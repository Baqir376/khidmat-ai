// ignore_for_file: constant_identifier_names

/// App-wide string translations (English + Pure Urdu + Roman Urdu)
class AppStrings {
  // ── App General ─────────────────────────────────────────────────
  static const String appName_en = 'KaamSaaz';
  static const String appName_ur = 'خدمت اے آئی';
  static const String appName_ru = 'KaamSaaz';

  // ── Home Screen ──────────────────────────────────────────────────
  static const String homeTitle_en = 'KaamSaaz';
  static const String homeTitle_ur = 'خدمت اے آئی';
  static const String homeTitle_ru = 'KaamSaaz';
  
  static const String homeSubtitle_en = "Pakistan's Smartest Home Services";
  static const String homeSubtitle_ur = 'پاکستان کی سمارٹ ہوم سروس';
  static const String homeSubtitle_ru = "Pakistan ki Sabse Smart Home Services";
  
  static const String searchHint_en = 'Describe what you need... (e.g., "mera AC kharab hai")';
  static const String searchHint_ur = 'اپنی ضرورت بتائیں... (مثلاً "میرا اے سی خراب ہے")';
  static const String searchHint_ru = "Apni zaroorat batayein... (e.g., 'mera AC kharab hai')";
  
  static const String findProviders_en = '🔍 Find Providers';
  static const String findProviders_ur = '🔍 خدمت گار ڈھونڈیں';
  static const String findProviders_ru = '🔍 Providers Dhundain';
  
  static const String myBookings_en = 'My Bookings';
  static const String myBookings_ur = 'میری بکنگز';
  static const String myBookings_ru = 'Meri Bookings';
  
  static const String nearby_en = 'Nearby';
  static const String nearby_ur = 'قریبی';
  static const String nearby_ru = 'Qareebi';
  
  static const String aiChat_en = 'AI Chat';
  static const String aiChat_ur = 'اے آئی چیٹ';
  static const String aiChat_ru = 'AI Chat';
  
  static const String logout_en = 'Logout';
  static const String logout_ur = 'لاگ آؤٹ';
  static const String logout_ru = 'Log Out';

  // ── AI Chatbot ───────────────────────────────────────────────────
  static const String chatTitle_en = 'AI Assistant';
  static const String chatTitle_ur = 'اے آئی اسسٹنٹ';
  static const String chatTitle_ru = 'AI Assistant';
  
  static const String chatSubtitle_en = 'Ask anything • Book services • Voice support';
  static const String chatSubtitle_ur = 'کچھ بھی پوچھیں • سروس بک کریں • آواز سے بات کریں';
  static const String chatSubtitle_ru = 'Kuch bhi poochain • Services book karain • Voice support';
  
  static const String chatHint_en = 'Type your message or use voice...';
  static const String chatHint_ur = 'پیغام لکھیں یا آواز استعمال کریں...';
  static const String chatHint_ru = 'Message likhein ya voice use karain...';
  
  static const String chatGreeting_en =
      "👋 Assalam o Alaikum! I'm your KaamSaaz assistant.\n\nYou can ask me anything in English, Urdu, or Roman Urdu:\n• \"Mera AC kharab hai\" → I'll find AC mechanics\n• \"Plumber chahiye kal subah\" → I'll book for tomorrow\n• Or just type what you need!\n\n🎤 You can also send a voice message!";
  static const String chatGreeting_ur =
      '👋 السلام علیکم! میں آپ کا خدمت اے آئی اسسٹنٹ ہوں۔\n\nآپ مجھ سے اردو، انگریزی یا رومن اردو میں پوچھ سکتے ہیں:\n• "میرا اے سی خراب ہے" → میں اے سی مکینک ڈھونڈوں گا\n• "کل صبح پلمبر چاہیے" → میں بکنگ کروں گا\n\n🎤 آواز کا پیغام بھی بھیج سکتے ہیں!';
  static const String chatGreeting_ru =
      "👋 Assalam-o-Alaikum! Main aapka KaamSaaz assistant hoon.\n\nAap mujh se English, Urdu ya Roman Urdu mein kuch bhi pooch sakte hain:\n• \"Mera AC kharab hai\" → Main AC mechanics dhundhunga\n• \"Plumber chahiye kal subha\" → Main booking kar lunga\n• Ya jo bhi zaroorat ho likhein!\n\n🎤 Aap voice message bhi bhej sakte hain!";

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

  static const Map<String, String> categories_ru = {
    'plumber': 'Plumber',
    'electrician': 'Bijli Wala / Electrician',
    'ac_mechanic': 'AC Mechanic',
    'house_maid': 'Kaam Wali / Maid',
    'carpenter': 'Carpenter',
    'painter': 'Painter',
    'gardener': 'Mali / Gardener',
    'tutor': 'Tutor / Ustad',
    'beautician': 'Beautician',
    'generator': 'Generator Mechanic',
    'welder': 'Welder',
    'tiler': 'Tiler / Mason',
  };

  // ── Booking Screen ────────────────────────────────────────────────
  static const String bookingTitle_en = 'Finding Providers';
  static const String bookingTitle_ur = 'خدمت گار ڈھونڈ رہے ہیں';
  static const String bookingTitle_ru = 'Providers Dhund Rahay Hain';
  
  static const String confirmBooking_en = 'Confirm Booking';
  static const String confirmBooking_ur = 'بکنگ کنفرم کریں';
  static const String confirmBooking_ru = 'Booking Confirm Karain';
  
  static const String noProviders_en = 'No providers found nearby';
  static const String noProviders_ur = 'قریب میں کوئی خدمت گار نہیں ملا';
  static const String noProviders_ru = 'Qareeb koi provider nahi mila';

  // ── Common ────────────────────────────────────────────────────────
  static const String ok_en = 'OK';
  static const String ok_ur = 'ٹھیک ہے';
  static const String ok_ru = 'Theek Hai';
  
  static const String cancel_en = 'Cancel';
  static const String cancel_ur = 'منسوخ';
  static const String cancel_ru = 'Cancel';
  
  static const String loading_en = 'Loading...';
  static const String loading_ur = 'لوڈ ہو رہا ہے...';
  static const String loading_ru = 'Load ho raha hai...';
  
  static const String error_en = 'Something went wrong';
  static const String error_ur = 'کچھ غلط ہو گیا';
  static const String error_ru = 'Kuch galat ho gaya';
  
  static const String retry_en = 'Retry';
  static const String retry_ur = 'دوبارہ کوشش کریں';
  static const String retry_ru = 'Dobara Koshish';
  
  static const String submit_en = 'Submit';
  static const String submit_ur = 'جمع کروائیں';
  static const String submit_ru = 'Submit';
  
  static const String rateReview_en = 'Rate & Review';
  static const String rateReview_ur = 'ریٹنگ دیں';
  static const String rateReview_ru = 'Rating dein';
}
