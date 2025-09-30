class SearchService {
  static List<Map<String, dynamic>> filterJobs({
    required List<Map<String, dynamic>> allJobs,
    required String searchQuery,
    required String selectedJobType,
    required String selectedLocation,
    required String selectedExperience,
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

      // Filter by salary range
      final salaryMinJob = job['salary_min'] ?? 0;
      final salaryMaxJob = job['salary_max'] ?? 0;
      final matchesSalary = (salaryMinJob >= salaryMin && salaryMinJob <= salaryMax) ||
          (salaryMaxJob >= salaryMin && salaryMaxJob <= salaryMax) ||
          (salaryMinJob <= salaryMin && salaryMaxJob >= salaryMax);

      return matchesSearch && matchesJobType && matchesLocation && matchesExperience && matchesSalary;
    }).toList();
  }

  static bool hasActiveFilters({
    required String selectedJobType,
    required String selectedLocation,
    required String selectedExperience,
    required double salaryMin,
    required double salaryMax,
  }) {
    return selectedJobType != 'all' ||
        selectedLocation != 'all' ||
        selectedExperience != 'all' ||
        salaryMin != 0 ||
        salaryMax != 500000;
  }
}
