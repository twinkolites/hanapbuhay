-- Reschedule Requests Table
-- Handles rescheduling of missed/no-show interviews

CREATE TABLE IF NOT EXISTS reschedule_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    original_event_id UUID NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    preferred_date DATE,
    preferred_start_time TIME,
    preferred_end_time TIME,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    new_start_time TIMESTAMPTZ,
    new_end_time TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_original_event ON reschedule_requests(original_event_id);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_requester ON reschedule_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_status ON reschedule_requests(status);
CREATE INDEX IF NOT EXISTS idx_reschedule_requests_created_at ON reschedule_requests(created_at);

-- RLS Policies
ALTER TABLE reschedule_requests ENABLE ROW LEVEL SECURITY;

-- Users can view reschedule requests for events they're involved in
CREATE POLICY "Users can view reschedule requests for their events" ON reschedule_requests
    FOR SELECT USING (
        requester_id = auth.uid() OR
        original_event_id IN (
            SELECT id FROM calendar_events 
            WHERE applicant_id = auth.uid() OR employer_id = auth.uid()
        )
    );

-- Users can create reschedule requests for events they're involved in
CREATE POLICY "Users can create reschedule requests for their events" ON reschedule_requests
    FOR INSERT WITH CHECK (
        requester_id = auth.uid() AND
        original_event_id IN (
            SELECT id FROM calendar_events 
            WHERE applicant_id = auth.uid() OR employer_id = auth.uid()
        )
    );

-- Users can update reschedule requests they created or for their events
CREATE POLICY "Users can update reschedule requests for their events" ON reschedule_requests
    FOR UPDATE USING (
        requester_id = auth.uid() OR
        original_event_id IN (
            SELECT id FROM calendar_events 
            WHERE applicant_id = auth.uid() OR employer_id = auth.uid()
        )
    );

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_reschedule_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_reschedule_requests_updated_at
    BEFORE UPDATE ON reschedule_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_reschedule_requests_updated_at();

-- Function to automatically detect no-show meetings
CREATE OR REPLACE FUNCTION detect_no_show_meetings()
RETURNS TABLE (
    event_id UUID,
    event_title TEXT,
    applicant_id UUID,
    employer_id UUID,
    end_time TIMESTAMPTZ,
    is_no_show BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ce.id as event_id,
        ce.title as event_title,
        ce.applicant_id,
        ce.employer_id,
        ce.end_time,
        CASE 
            WHEN ia.applicant_joined_at IS NULL THEN true
            ELSE false
        END as is_no_show
    FROM calendar_events ce
    LEFT JOIN interview_attendance ia ON ce.id = ia.event_id
    WHERE ce.type = 'interview'
        AND ce.status = 'completed'
        AND ce.end_time < NOW()
        AND ce.end_time > NOW() - INTERVAL '7 days'
        AND (ia.applicant_joined_at IS NULL OR ia.is_no_show = true);
END;
$$ LANGUAGE plpgsql;

-- Function to get reschedule statistics
CREATE OR REPLACE FUNCTION get_reschedule_stats(user_id UUID)
RETURNS TABLE (
    total_requests INTEGER,
    pending_requests INTEGER,
    approved_requests INTEGER,
    rejected_requests INTEGER,
    no_show_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH user_events AS (
        SELECT id FROM calendar_events 
        WHERE applicant_id = user_id OR employer_id = user_id
    ),
    reschedule_stats AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'pending') as pending,
            COUNT(*) FILTER (WHERE status = 'approved') as approved,
            COUNT(*) FILTER (WHERE status = 'rejected') as rejected
        FROM reschedule_requests rr
        WHERE rr.original_event_id IN (SELECT id FROM user_events)
    ),
    no_show_stats AS (
        SELECT 
            COUNT(*) as total_meetings,
            COUNT(*) FILTER (WHERE ia.applicant_joined_at IS NULL OR ia.is_no_show = true) as no_shows
        FROM calendar_events ce
        LEFT JOIN interview_attendance ia ON ce.id = ia.event_id
        WHERE ce.applicant_id = user_id
            AND ce.type = 'interview'
            AND ce.status = 'completed'
            AND ce.end_time < NOW()
            AND ce.end_time > NOW() - INTERVAL '30 days'
    )
    SELECT 
        COALESCE(rs.total, 0)::INTEGER as total_requests,
        COALESCE(rs.pending, 0)::INTEGER as pending_requests,
        COALESCE(rs.approved, 0)::INTEGER as approved_requests,
        COALESCE(rs.rejected, 0)::INTEGER as rejected_requests,
        CASE 
            WHEN ns.total_meetings > 0 THEN 
                ROUND((ns.no_shows::NUMERIC / ns.total_meetings) * 100, 2)
            ELSE 0
        END as no_show_rate
    FROM reschedule_stats rs, no_show_stats ns;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON reschedule_requests TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
