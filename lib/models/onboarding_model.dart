class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;
  final String? subtitle;
  final List<String>? features;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
    this.subtitle,
    this.features,
  });
}