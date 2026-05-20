// ignore_for_file: constant_identifier_names

/// App-wide string translations (English + Urdu)
class AppStrings {
  // ── App General ─────────────────────────────────────────────────
  static const String appName_en = 'Khidmat AI';
  static const String appName_ur = 'خدمت اے آئی';

  // ── Home Screen ──────────────────────────────────────────────────
  static const String homeTitle_en = 'Khidmat AI';
  static const String homeTitle_ur = 'خدمت اے آئی';
  static const String homeSubtitle_en = "Pakistan's Smartest Home Services";
  static const String homeSubtitle_ur = 'پاکستان کی سمارٹ ہوم سروس';
  static const String searchHint_en = 'Describe what you need... (e.g., "mera AC kharab hai")';
  static const String searchHint_ur = 'اپنی ضرورت بتائیں... (مثلاً "میرا اے سی خراب ہے")';
  static const String findProviders_en = '🔍 Find Providers';
  static const String findProviders_ur = '🔍 خدمت گار ڈھونڈیں';
  static const String myBookings_en = 'My Bookings';
  static const String myBookings_ur = 'میری بکنگز';
  static const String nearby_en = 'Nearby';
  static const String nearby_ur = 'قریبی';
  static const String aiChat_en = 'AI Chat';
  static const String aiChat_ur = 'اے آئی چیٹ';
  static const String logout_en = 'Logout';
  static const String logout_ur = 'لاگ آؤٹ';

  // ── AI Chatbot ───────────────────────────────────────────────────
  static const String chatTitle_en = 'AI Assistant';
  static const String chatTitle_ur = 'اے آئی اسسٹنٹ';
  static const String chatSubtitle_en = 'Ask anything • Book services • Voice support';
  static const String chatSubtitle_ur = 'کچھ بھی پوچھیں • سروس بک کریں • آواز سے بات کریں';
  static const String chatHint_en = 'Type your message or use voice...';
  static const String chatHint_ur = 'پیغام لکھیں یا آواز استعمال کریں...';
  static const String chatGreeting_en =
      "👋 Assalam o Alaikum! I'm your Khidmat AI assistant.\n\nYou can ask me anything in English, Urdu, or Roman Urdu:\n• \"Mera AC kharab hai\" → I'll find AC mechanics\n• \"Plumber chahiye kal subah\" → I'll book for tomorrow\n• Or just type what you need!\n\n🎤 You can also send a voice message!";
  static const String chatGreeting_ur =
      '👋 السلام علیکم! میں آپ کا خدمت اے آئی اسسٹنٹ ہوں۔\n\nآپ مجھ سے اردو، انگریزی یا رومن اردو میں پوچھ سکتے ہیں:\n• "میرا اے سی خراب ہے" → میں اے سی مکینک ڈھونڈوں گا\n• "کل صبح پلمبر چاہیے" → میں بکنگ کروں گا\n\n🎤 آواز کا پیغام بھی بھیج سکتے ہیں!';

  // ── Categories ────────────────────────────────────────────────────
  static const Map<String, String> categories_ur = {
    'plumber': 'پلمبر',
    'electrician': 'بجلی کا مستری',
    'ac_mechanic': 'اے سی مکینک',
    'house_maid': 'گھریلو ملازمہ',
    'carpenter': 'بڑھئی',
    'painter': 'رنگ ساز',
    'gardener': 'مالی',
    'tutor': 'استاد / ٹیوٹر',
    'beautician': 'بیوٹیشن',
    'generator': 'جنریٹر مکینک',
    'welder': 'ویلڈر',
    'tiler': 'ٹائل ماسٹر',
  };

  // ── Booking Screen ────────────────────────────────────────────────
  static const String bookingTitle_en = 'Finding Providers';
  static const String bookingTitle_ur = 'خدمت گار ڈھونڈ رہے ہیں';
  static const String confirmBooking_en = 'Confirm Booking';
  static const String confirmBooking_ur = 'بکنگ کنفرم کریں';
  static const String noProviders_en = 'No providers found nearby';
  static const String noProviders_ur = 'قریب میں کوئی خدمت گار نہیں ملا';

  // ── Common ────────────────────────────────────────────────────────
  static const String ok_en = 'OK';
  static const String ok_ur = 'ٹھیک ہے';
  static const String cancel_en = 'Cancel';
  static const String cancel_ur = 'منسوخ';
  static const String loading_en = 'Loading...';
  static const String loading_ur = 'لوڈ ہو رہا ہے...';
  static const String error_en = 'Something went wrong';
  static const String error_ur = 'کچھ غلط ہو گیا';
  static const String retry_en = 'Retry';
  static const String retry_ur = 'دوبارہ کوشش کریں';
  static const String submit_en = 'Submit';
  static const String submit_ur = 'جمع کروائیں';
  static const String rateReview_en = 'Rate & Review';
  static const String rateReview_ur = 'ریٹنگ دیں';
}
