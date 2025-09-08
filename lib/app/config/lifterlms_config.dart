/// LifterLMS Configuration
/// 
/// IMPORTANT: Update these values with your actual LifterLMS credentials
/// For production, consider using environment variables or secure storage
/// 
/// To get your API credentials:
/// 1. Install LifterLMS REST API plugin on your WordPress site
/// 2. Go to LifterLMS > Settings > REST API
/// 3. Click "Add Key" and generate your credentials
class LifterLMSConfig {
  // REPLACE THESE WITH YOUR ACTUAL VALUES
  static const String siteUrl = 'https://your-lifterlms-site.com';
  static const String consumerKey = 'ck_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  static const String consumerSecret = 'cs_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
  
  // Optional: Different configs for different environments
  static const Map<String, dynamic> development = {
    'siteUrl': 'https://dev.your-site.com',
    'consumerKey': 'ck_dev_key',
    'consumerSecret': 'cs_dev_secret',
  };
  
  static const Map<String, dynamic> staging = {
    'siteUrl': 'https://staging.your-site.com',
    'consumerKey': 'ck_staging_key',
    'consumerSecret': 'cs_staging_secret',
  };
  
  static const Map<String, dynamic> production = {
    'siteUrl': 'https://your-site.com',
    'consumerKey': 'ck_production_key',
    'consumerSecret': 'cs_production_secret',
  };
  
  // Get config based on environment
  static Map<String, dynamic> getConfig(String environment) {
    switch (environment) {
      case 'development':
        return development;
      case 'staging':
        return staging;
      case 'production':
        return production;
      default:
        return {
          'siteUrl': siteUrl,
          'consumerKey': consumerKey,
          'consumerSecret': consumerSecret,
        };
    }
  }
}