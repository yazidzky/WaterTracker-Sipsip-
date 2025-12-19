import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Settings
      'settings': 'Settings',
      'sound': 'Sound',
      'language': 'Language',
      'darkMode': 'Dark Mode',
      'version': 'Version',
      'reminder': 'Reminder',
      'ring': 'Ring',
      'vibrate': 'Vibrate',
      'silent': 'Silent',
      'save': 'Save',
      'close': 'Close',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'updateSuccess': 'Updated successfully',
      'updateFailed': 'Failed to update',
      
      // Home
      'goodMorning': 'Good Morning,',
      'goodAfternoon': 'Good Afternoon,',
      'goodEvening': 'Good Evening,',
      'goodNight': 'Good Night,',
      'of': 'of',
      'todayRecord': "Today's Record",
      'failedToAdd': 'Failed to add water',
      'noData': 'No Data',
      
      // Profile
      'myProfile': 'My Profile',
      'editProfile': 'Edit Profile',
      'logout': 'Logout',
      'deleteAccount': 'Delete Account',
      'deleteAccountConfirmation': 'Are you sure you want to delete this account?',
      'name': 'Name',
      'email': 'Email',
      'gender': 'Gender',
      'age': 'Age',
      'weight': 'Weight',
      'height': 'Height',
      'wakeUpTime': 'Wake Up Time',
      'bedTime': 'Bed Time',
      'activityLevel': 'Activity Level',
      'male': 'Male',
      'female': 'Female',
      'dailyGoal': 'Daily Goal',
      'editHydrationFactors': 'Edit Hydration Factors',
      'healthCondition': 'Health Condition',
      'selectCondition': 'Select Condition',
      'selectGender': 'Select Gender',
      'chooseAvatar': 'Choose Avatar',
      'others': 'Others',
      'writeHere': 'Write here (Optional)',
      'continue': 'Continue',
      
      // Statistics
      'statistics': 'Statistics',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'dailyAverage': 'Daily Average',
      'completion': 'Completion',
      'completionRate': 'Completion Rate',
      'drinkFrequency': 'Drink Frequency',
      'habits': 'Habits',
      'highlights': 'Highlights',
      
      // Auth
      'login': 'Login',
      'register': 'Register',
      'password': 'Password',
      'forgotPassword': 'Forgot Password?',
      'dontHaveAccount': "Don't have an account?",
      'alreadyHaveAccount': 'Already have an account?',
      'orLoginWith': 'Or login with',
      
      // Reminder
      'setReminder': 'Set Reminder',
      'interval': 'Interval',
      'startTime': 'Start Time',
      'endTime': 'End Time',
      'selectInterval': 'Select Interval',
      'today': 'Today',
      'hour': 'Hour',
      'hours': 'Hours',
      'mins': 'Mins',

      // Login/Register
      'enterEmail': 'Enter your email',
      'enterPassword': 'Enter your password',
      'enterName': 'Enter your name',
      'howCanICallYou': 'How can I call you?',
      'continueWithGoogle': 'Continue with Google',
      'acceptTerms': 'By signing in you are accepting terms and conditions & privacy policy.',

      // Onboarding
      'whatIsYourGender': 'What is your\ngender?',
      'howOldAreYou': 'How old\nare you?',
      'whatIsYourWeight': 'What is your\nweight?',
      'whatTimeWakeUp': 'What time\ndo you usually wake up?',
      'whatTimeSleep': 'What time\ndo you usually go to bed?',
      'doYouHaveHealthCondition': 'Do you have any\nhealth conditions?',
      'yes': 'Yes',
      'no': 'No',
      'diabetes': 'Diabetes',
      'dehydration': 'Dehydration',
      'hypertension': 'Hypertension',
      'kidneyIssue': 'Kidney Issues',
      'gastricAcid': 'Gastric Acid',
      'pregnantBreastfeeding': 'Pregnant/Breastfeeding',

      // Statistics Detail
      'morning': 'Morning',
      'afternoon': 'Afternoon',
      'night': 'Night',
      'longestStreak': 'Longest Streak',
      'bestHydration': 'Best Hydration',
      'noWaterRecord': 'No water record yet.',
    },
    'id': {
      // Settings
      'settings': 'Pengaturan',
      'sound': 'Suara',
      'language': 'Bahasa',
      'darkMode': 'Mode Gelap',
      'version': 'Versi',
      'reminder': 'Pengingat',
      'ring': 'Dering',
      'vibrate': 'Getar',
      'silent': 'Senyap',
      'save': 'Simpan',
      'close': 'Tutup',
      'cancel': 'Batal',
      'delete': 'Hapus',
      'updateSuccess': 'Berhasil diperbarui',
      'updateFailed': 'Gagal memperbarui',
      
      // Home
      'goodMorning': 'Selamat pagi,',
      'goodAfternoon': 'Selamat siang,',
      'goodEvening': 'Selamat sore,',
      'goodNight': 'Selamat malam,',
      'of': 'dari',
      'todayRecord': 'Catatan hari ini',
      'failedToAdd': 'Gagal menambahkan air',
      'noData': 'Belum ada data',
      
      // Profile
      'myProfile': 'Profil Saya',
      'editProfile': 'Edit Profil',
      'logout': 'Keluar',
      'deleteAccount': 'Hapus Akun',
      'deleteAccountConfirmation': 'Apakah anda yakin ingin menghapus akun ini?',
      'name': 'Nama',
      'email': 'Email',
      'gender': 'Jenis Kelamin',
      'age': 'Usia',
      'weight': 'Berat Badan',
      'height': 'Tinggi Badan',
      'wakeUpTime': 'Bangun Tidur',
      'bedTime': 'Mulai Tidur',
      'activityLevel': 'Aktivitas',
      'male': 'Pria',
      'female': 'Wanita',
      'dailyGoal': 'Target Harian',
      'editHydrationFactors': 'Edit Faktor Hidrasi',
      'healthCondition': 'Kondisi Kesehatan',
      'selectCondition': 'Pilih Kondisi yang Sesuai',
      'selectGender': 'Pilih Jenis Kelamin',
      'chooseAvatar': 'Pilih Avatar',
      'others': 'Lainnya',
      'writeHere': 'Tulis di sini (Optional)',
      'continue': 'Lanjutkan',
      
      // Statistics
      'statistics': 'Statistik',
      'weekly': 'Mingguan',
      'monthly': 'Bulanan',
      'dailyAverage': 'Rata-rata Harian',
      'completion': 'Pencapaian',
      'completionRate': 'Tingkat Penyelesaian',
      'drinkFrequency': 'Frekuensi Minum',
      'habits': 'Kebiasaan',
      'highlights': 'Sorotan',
      
      // Auth
      'login': 'Masuk',
      'register': 'Daftar',
      'password': 'Kata Sandi',
      'forgotPassword': 'Lupa Password?',
      'dontHaveAccount': 'Belum punya akun?',
      'alreadyHaveAccount': 'Sudah punya akun?',
      'orLoginWith': 'Atau masuk dengan',
      
      // Reminder
      'setReminder': 'Atur Pengingat',
      'interval': 'Interval',
      'startTime': 'Waktu Mulai',
      'endTime': 'Waktu Selesai',
      'selectInterval': 'Pilih Interval',
      'today': 'Hari ini',
      'hour': 'Jam',
      'hours': 'Jam',
      'mins': 'Mnt',

      // Login/Register
      'enterEmail': 'Masukkan email-mu',
      'enterPassword': 'Masukkan password-mu',
      'enterName': 'Nama kamu',
      'howCanICallYou': 'Bagaimana aku bisa memanggilmu?',
      'continueWithGoogle': 'Lanjutkan dengan Google',
      'acceptTerms': 'Dengan masuk, Anda menyetujui syarat & ketentuan serta kebijakan privasi.',

      // Onboarding
      'whatIsYourGender': 'Apa jenis\nkelaminmu?',
      'howOldAreYou': 'Berapa\nUsiamu?',
      'whatIsYourWeight': 'Berapa berat\nbadanmu?',
      'whatTimeWakeUp': 'Jam berapa\nkamu biasanya bangun?',
      'whatTimeSleep': 'Jam berapa\nkamu biasanya tidur?',
      'doYouHaveHealthCondition': 'Apakah kamu memiliki\nkondisi kesehatan\ntertentu?',
      'yes': 'Ya',
      'no': 'Tidak',
      'diabetes': 'Diabetes',
      'dehydration': 'Dehidrasi',
      'hypertension': 'Hipertensi',
      'kidneyIssue': 'Masalah Ginjal',
      'gastricAcid': 'Asam Lambung',

      'pregnantBreastfeeding': 'Hamil/Menyusui',

      // Statistics Detail
      'morning': 'Pagi',
      'afternoon': 'Siang',
      'night': 'Malam',
      'longestStreak': 'Streak Terpanjang',
      'bestHydration': 'Hidrasi Terbaik',
      'noWaterRecord': 'Belum ada catatan air minum.',
    },
  };

  Future<bool> load() async {
    _localizedStrings = _localizedValues[locale.languageCode] ?? _localizedValues['id']!;
    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'id'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
