class SearchService {
  static List<Map<String, dynamic>> filterJobs({
    required List<Map<String, dynamic>> allJobs,
    required String searchQuery,
    required String selectedJobType,
    required String selectedLocation,
    required String selectedExperience,
    required String selectedIndustry,
    required String selectedCompanySize,
    required bool showRemoteOnly,
    required double salaryMin,
    required double salaryMax,
  }) {
    return allJobs.where((job) {
      // Search by title, company name, or location
      final title = (job['title'] ?? '').toString().toLowerCase();
      final company = (job['companies']?['name'] ?? '').toString().toLowerCase();
      final location = (job['location'] ?? '').toString().toLowerCase();
      final description = (job['description'] ?? '').toString().toLowerCase();
      
      final matchesSearch = searchQuery.isEmpty ||
          title.contains(searchQuery) ||
          company.contains(searchQuery) ||
          location.contains(searchQuery) ||
          description.contains(searchQuery);

      // Filter by job type
      final matchesJobType = selectedJobType == 'all' || 
          job['type'] == selectedJobType;

      // Filter by location
      final matchesLocation = selectedLocation == 'all' ||
          (job['location'] ?? '').toLowerCase().contains(selectedLocation.toLowerCase());

      // Filter by experience level
      final matchesExperience = selectedExperience == 'all' ||
          (job['experience_level'] ?? '').toLowerCase().contains(selectedExperience.toLowerCase());

      // Filter by industry
      final matchesIndustry = selectedIndustry == 'all' ||
          (job['companies']?['industry'] ?? '').toLowerCase().contains(selectedIndustry.toLowerCase());

      // Filter by company size
      final matchesCompanySize = selectedCompanySize == 'all' ||
          (job['companies']?['company_size'] ?? '').toLowerCase().contains(selectedCompanySize.toLowerCase());

      // Filter by remote work
      final matchesRemote = !showRemoteOnly || 
          (job['type'] == 'remote') ||
          (job['location'] ?? '').toLowerCase().contains('remote');

      // Filter by salary range
      final salaryMinJob = job['salary_min'] ?? 0;
      final salaryMaxJob = job['salary_max'] ?? 0;
      final matchesSalary = (salaryMinJob >= salaryMin && salaryMinJob <= salaryMax) ||
          (salaryMaxJob >= salaryMin && salaryMaxJob <= salaryMax) ||
          (salaryMinJob <= salaryMin && salaryMaxJob >= salaryMax);

      return matchesSearch && matchesJobType && matchesLocation && matchesExperience && 
             matchesIndustry && matchesCompanySize && matchesRemote && matchesSalary;
    }).toList();
  }

  static bool hasActiveFilters({
    required String selectedJobType,
    required String selectedLocation,
    required String selectedExperience,
    required String selectedIndustry,
    required String selectedCompanySize,
    required bool showRemoteOnly,
    required double salaryMin,
    required double salaryMax,
  }) {
    return selectedJobType != 'all' ||
        selectedLocation != 'all' ||
        selectedExperience != 'all' ||
        selectedIndustry != 'all' ||
        selectedCompanySize != 'all' ||
        showRemoteOnly ||
        salaryMin != 0 ||
        salaryMax != 500000;
  }
}
