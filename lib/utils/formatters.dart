class Formatters {
  static String formatSalaryRange(int? min, int? max) {
    if (min != null && max != null) {
      return '₱${formatNumber(min)} - ₱${formatNumber(max)}';
    } else if (min != null) {
      return '₱${formatNumber(min)}+';
    } else if (max != null) {
      return 'Up to ₱${formatNumber(max)}';
    }
    return 'Salary negotiable';
  }

  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
  }

  static String formatJobTypeDisplay(String type) {
    switch (type) {
      case 'full_time':
        return 'Full Time';
      case 'part_time':
        return 'Part Time';
      case 'contract':
        return 'Contract';
      case 'temporary':
        return 'Temporary';
      case 'internship':
        return 'Internship';
      case 'remote':
        return 'Remote';
      default:
        return type.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  static String formatExperienceDisplay(String experience) {
    switch (experience.toLowerCase()) {
      case 'entry_level':
        return 'Entry Level';
      case 'mid_level':
        return 'Mid Level';
      case 'senior':
        return 'Senior';
      case 'executive':
        return 'Executive';
      default:
        return experience.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }
}
