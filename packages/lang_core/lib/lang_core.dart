/// Shared language-learning core: text segmentation, script/language
/// detection and SRS scheduling math.
///
/// Pure Dart — no Flutter dependency. Hosts implement
/// [DictionaryDb] over their own storage and map [ScheduleResult] onto
/// their own card models.
library lang_core;

export 'src/dictionary_db.dart';
export 'src/language_detector.dart';
export 'src/script_ranges.dart';
export 'src/srs_scheduler.dart';
export 'src/token.dart';
export 'src/tokenizer.dart';
