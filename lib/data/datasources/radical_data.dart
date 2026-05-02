class KangxiRadical {
  final int number;
  final String character;
  final String simplified;
  final int strokes;
  final String nameJa;
  final String nameEn;
  final String position;
  final List<String> variants;

  const KangxiRadical({
    required this.number,
    required this.character,
    this.simplified = '',
    required this.strokes,
    required this.nameJa,
    required this.nameEn,
    this.position = '',
    this.variants = const [],
  });

  String get displayChar => simplified.isNotEmpty ? simplified : character;
}

class RadicalData {
  static const List<KangxiRadical> all = [
    KangxiRadical(number: 1, character: '一', strokes: 1, nameJa: 'いち', nameEn: 'one', position: 'top/bottom'),
    KangxiRadical(number: 2, character: '丨', strokes: 1, nameJa: 'ぼう', nameEn: 'line', position: 'center'),
    KangxiRadical(number: 3, character: '丶', strokes: 1, nameJa: 'てん', nameEn: 'dot', position: 'various'),
    KangxiRadical(number: 4, character: '丿', strokes: 1, nameJa: 'の', nameEn: 'bend', position: 'left/top'),
    KangxiRadical(number: 5, character: '乙', strokes: 1, nameJa: 'おつ', nameEn: 'second', position: 'various'),
    KangxiRadical(number: 6, character: '亅', strokes: 1, nameJa: 'はねぼう', nameEn: 'hook', position: 'bottom'),
    KangxiRadical(number: 7, character: '二', strokes: 2, nameJa: 'に', nameEn: 'two', position: 'top/bottom'),
    KangxiRadical(number: 8, character: '亠', strokes: 2, nameJa: 'なべぶた', nameEn: 'lid', position: 'top'),
    KangxiRadical(number: 9, character: '人', strokes: 2, nameJa: 'ひと', nameEn: 'person', position: 'various', variants: ['亻']),
    KangxiRadical(number: 10, character: '儿', strokes: 2, nameJa: 'ひとあし', nameEn: 'legs', position: 'bottom'),
    KangxiRadical(number: 11, character: '入', strokes: 2, nameJa: 'いる', nameEn: 'enter', position: 'various'),
    KangxiRadical(number: 12, character: '八', strokes: 2, nameJa: 'はち', nameEn: 'eight', position: 'top/bottom'),
    KangxiRadical(number: 13, character: '冂', strokes: 2, nameJa: 'まきがまえ', nameEn: 'down box', position: 'around'),
    KangxiRadical(number: 14, character: '冖', strokes: 2, nameJa: 'わかんむり', nameEn: 'cover', position: 'top'),
    KangxiRadical(number: 15, character: '冫', strokes: 2, nameJa: 'にすい', nameEn: 'ice', position: 'left'),
    KangxiRadical(number: 16, character: '几', strokes: 2, nameJa: 'きにょう', nameEn: 'table', position: 'various'),
    KangxiRadical(number: 17, character: '凵', strokes: 2, nameJa: 'うけばこ', nameEn: 'open box', position: 'around'),
    KangxiRadical(number: 18, character: '刀', strokes: 2, nameJa: 'かたな', nameEn: 'knife', position: 'right', variants: ['刂']),
    KangxiRadical(number: 19, character: '力', strokes: 2, nameJa: 'ちから', nameEn: 'power', position: 'right'),
    KangxiRadical(number: 20, character: '勹', strokes: 2, nameJa: 'つつみがまえ', nameEn: 'wrap', position: 'around'),
    KangxiRadical(number: 21, character: '匕', strokes: 2, nameJa: 'ひ', nameEn: 'spoon', position: 'right'),
    KangxiRadical(number: 22, character: '匚', strokes: 2, nameJa: 'はこがまえ', nameEn: 'right open box', position: 'around'),
    KangxiRadical(number: 23, character: '十', strokes: 2, nameJa: 'じゅう', nameEn: 'ten', position: 'center'),
    KangxiRadical(number: 24, character: '卜', strokes: 2, nameJa: 'ぼく', nameEn: 'divination', position: 'right'),
    KangxiRadical(number: 25, character: '卩', strokes: 2, nameJa: 'ふしづくり', nameEn: 'seal', position: 'right', variants: ['㔾']),
    KangxiRadical(number: 26, character: '厂', strokes: 2, nameJa: 'がんだれ', nameEn: 'cliff', position: 'left/top'),
    KangxiRadical(number: 27, character: '厶', strokes: 2, nameJa: 'む', nameEn: 'private', position: 'various'),
    KangxiRadical(number: 28, character: '又', strokes: 2, nameJa: 'また', nameEn: 'again', position: 'right'),
    KangxiRadical(number: 29, character: '口', strokes: 3, nameJa: 'くち', nameEn: 'mouth', position: 'left'),
    KangxiRadical(number: 30, character: '囗', strokes: 3, nameJa: 'くにがまえ', nameEn: 'enclosure', position: 'around'),
    KangxiRadical(number: 31, character: '土', strokes: 3, nameJa: 'つち', nameEn: 'earth', position: 'left/bottom'),
    KangxiRadical(number: 32, character: '士', strokes: 3, nameJa: 'さむらい', nameEn: 'scholar', position: 'top/bottom'),
    KangxiRadical(number: 33, character: '夂', strokes: 3, nameJa: 'ふゆがしら', nameEn: 'go', position: 'bottom'),
    KangxiRadical(number: 34, character: '夊', strokes: 3, nameJa: 'すいにょう', nameEn: 'go slowly', position: 'bottom'),
    KangxiRadical(number: 35, character: '夕', strokes: 3, nameJa: 'ゆう', nameEn: 'evening', position: 'right'),
    KangxiRadical(number: 36, character: '大', strokes: 3, nameJa: 'だい', nameEn: 'big', position: 'top/bottom'),
    KangxiRadical(number: 37, character: '女', strokes: 3, nameJa: 'おんな', nameEn: 'woman', position: 'left'),
    KangxiRadical(number: 38, character: '子', strokes: 3, nameJa: 'こ', nameEn: 'child', position: 'left/bottom'),
    KangxiRadical(number: 39, character: '宀', strokes: 3, nameJa: 'うかんむり', nameEn: 'roof', position: 'top'),
    KangxiRadical(number: 40, character: '寸', strokes: 3, nameJa: 'すん', nameEn: 'inch', position: 'bottom'),
    KangxiRadical(number: 41, character: '小', strokes: 3, nameJa: 'しょう', nameEn: 'small', position: 'various', variants: ['⺌', '⺍']),
    KangxiRadical(number: 42, character: '尢', strokes: 3, nameJa: 'まげあし', nameEn: 'lame', position: 'various', variants: ['尣']),
    KangxiRadical(number: 43, character: '尸', strokes: 3, nameJa: 'しかばね', nameEn: 'corpse', position: 'top/left'),
    KangxiRadical(number: 44, character: '屮', strokes: 3, nameJa: 'てつ', nameEn: 'sprout', position: 'various'),
    KangxiRadical(number: 45, character: '山', strokes: 3, nameJa: 'やま', nameEn: 'mountain', position: 'top/left'),
    KangxiRadical(number: 46, character: '巛', strokes: 3, nameJa: 'かわ', nameEn: 'river', position: 'top/left', variants: ['川']),
    KangxiRadical(number: 47, character: '工', strokes: 3, nameJa: 'こう', nameEn: 'work', position: 'left'),
    KangxiRadical(number: 48, character: '己', strokes: 3, nameJa: 'き', nameEn: 'self', position: 'various', variants: ['已', '巳']),
    KangxiRadical(number: 49, character: '巾', strokes: 3, nameJa: 'はば', nameEn: 'turban', position: 'left/top'),
    KangxiRadical(number: 50, character: '干', strokes: 3, nameJa: 'ほす', nameEn: 'dry', position: 'various'),
    KangxiRadical(number: 51, character: '幺', strokes: 3, nameJa: 'よう', nameEn: 'short thread', position: 'various'),
    KangxiRadical(number: 52, character: '广', strokes: 3, nameJa: 'まだれ', nameEn: 'dotted cliff', position: 'top'),
    KangxiRadical(number: 53, character: '廴', strokes: 3, nameJa: 'えんにょう', nameEn: 'long stride', position: 'bottom/left'),
    KangxiRadical(number: 54, character: '廾', strokes: 3, nameJa: 'にじゅうあし', nameEn: 'twenty', position: 'bottom', variants: ['廿']),
    KangxiRadical(number: 55, character: '弋', strokes: 3, nameJa: 'しき', nameEn: 'shoot', position: 'right'),
    KangxiRadical(number: 56, character: '弓', strokes: 3, nameJa: 'ゆみ', nameEn: 'bow', position: 'left/bottom'),
    KangxiRadical(number: 57, character: '彐', strokes: 3, nameJa: 'けいがしら', nameEn: 'snout', position: 'various', variants: ['彑']),
    KangxiRadical(number: 58, character: '彡', strokes: 3, nameJa: 'さんづくり', nameEn: 'bristle', position: 'right'),
    KangxiRadical(number: 59, character: '彳', strokes: 3, nameJa: 'ぎょうにんべん', nameEn: 'step', position: 'left'),
    KangxiRadical(number: 60, character: '心', strokes: 3, nameJa: 'こころ', nameEn: 'heart', position: 'bottom', variants: ['忄']),
    KangxiRadical(number: 61, character: '戈', strokes: 4, nameJa: 'ほこ', nameEn: 'halberd', position: 'right'),
    KangxiRadical(number: 62, character: '戶', strokes: 4, nameJa: 'と', nameEn: 'door', position: 'various', variants: ['户', '戸']),
    KangxiRadical(number: 63, character: '手', strokes: 4, nameJa: 'て', nameEn: 'hand', position: 'left/bottom', variants: ['扌', '龵']),
    KangxiRadical(number: 64, character: '支', strokes: 4, nameJa: 'えだにょう', nameEn: 'branch', position: 'right'),
    KangxiRadical(number: 65, character: '攵', strokes: 4, nameJa: 'のぶ', nameEn: 'rap', position: 'right', variants: ['攴']),
    KangxiRadical(number: 66, character: '文', strokes: 4, nameJa: 'ぶん', nameEn: 'literature', position: 'top/right'),
    KangxiRadical(number: 67, character: '斗', strokes: 4, nameJa: 'と', nameEn: 'dipper', position: 'right'),
    KangxiRadical(number: 68, character: '斤', strokes: 4, nameJa: 'きん', nameEn: 'axe', position: 'right'),
    KangxiRadical(number: 69, character: '方', strokes: 4, nameJa: 'ほう', nameEn: 'square', position: 'left'),
    KangxiRadical(number: 70, character: '无', strokes: 4, nameJa: 'なき', nameEn: 'not', position: 'various'),
    KangxiRadical(number: 71, character: '日', strokes: 4, nameJa: 'ひ', nameEn: 'sun/day', position: 'left/top'),
    KangxiRadical(number: 72, character: '曰', strokes: 4, nameJa: 'いわく', nameEn: 'say', position: 'top'),
    KangxiRadical(number: 73, character: '月', strokes: 4, nameJa: 'つき', nameEn: 'moon', position: 'left/bottom'),
    KangxiRadical(number: 74, character: '木', strokes: 4, nameJa: 'き', nameEn: 'tree/wood', position: 'left/bottom', variants: ['朩']),
    KangxiRadical(number: 75, character: '欠', strokes: 4, nameJa: 'あくび', nameEn: 'lack', position: 'right'),
    KangxiRadical(number: 76, character: '止', strokes: 4, nameJa: 'とめる', nameEn: 'stop', position: 'left'),
    KangxiRadical(number: 77, character: '歹', strokes: 4, nameJa: 'がつ', nameEn: 'death', position: 'left', variants: ['歺']),
    KangxiRadical(number: 78, character: '殳', strokes: 4, nameJa: 'るまた', nameEn: 'weapon', position: 'right'),
    KangxiRadical(number: 79, character: '毋', strokes: 4, nameJa: 'なかれ', nameEn: 'do not', position: 'various', variants: ['母']),
    KangxiRadical(number: 80, character: '气', strokes: 4, nameJa: 'きがまえ', nameEn: 'steam', position: 'around'),
    KangxiRadical(number: 81, character: '水', strokes: 4, nameJa: 'みず', nameEn: 'water', position: 'bottom', variants: ['氵', '氺']),
    KangxiRadical(number: 82, character: '火', strokes: 4, nameJa: 'ひ', nameEn: 'fire', position: 'left/bottom', variants: ['灬']),
    KangxiRadical(number: 83, character: '爪', strokes: 4, nameJa: 'つめ', nameEn: 'claw', position: 'top', variants: ['爫']),
    KangxiRadical(number: 84, character: '父', strokes: 4, nameJa: 'ちち', nameEn: 'father', position: 'top'),
    KangxiRadical(number: 85, character: '爻', strokes: 4, nameJa: 'こう', nameEn: 'line', position: 'various'),
    KangxiRadical(number: 86, character: '爿', strokes: 4, nameJa: 'しょう', nameEn: 'half tree', position: 'left', variants: ['片']),
    KangxiRadical(number: 87, character: '犬', strokes: 4, nameJa: 'いぬ', nameEn: 'dog', position: 'left', variants: ['犭']),
    KangxiRadical(number: 88, character: '玄', strokes: 5, nameJa: 'げん', nameEn: 'profound', position: 'various'),
    KangxiRadical(number: 89, character: '玉', strokes: 5, nameJa: 'たま', nameEn: 'jade', position: 'left/bottom', variants: ['王']),
    KangxiRadical(number: 90, character: '瓜', strokes: 5, nameJa: 'うり', nameEn: 'melon', position: 'various'),
    KangxiRadical(number: 91, character: '瓦', strokes: 5, nameJa: 'かわら', nameEn: 'tile', position: 'right/bottom'),
    KangxiRadical(number: 92, character: '甘', strokes: 5, nameJa: 'あまい', nameEn: 'sweet', position: 'various'),
    KangxiRadical(number: 93, character: '生', strokes: 5, nameJa: 'いきる', nameEn: 'life', position: 'various'),
    KangxiRadical(number: 94, character: '用', strokes: 5, nameJa: 'もちいる', nameEn: 'use', position: 'various'),
    KangxiRadical(number: 95, character: '田', strokes: 5, nameJa: 'た', nameEn: 'field', position: 'left/bottom'),
    KangxiRadical(number: 96, character: '疋', strokes: 5, nameJa: 'ひき', nameEn: 'bolt of cloth', position: 'various'),
    KangxiRadical(number: 97, character: '疒', strokes: 5, nameJa: 'やまいだれ', nameEn: 'sickness', position: 'top'),
    KangxiRadical(number: 98, character: '癶', strokes: 5, nameJa: 'はつがしら', nameEn: 'dotted tent', position: 'top'),
    KangxiRadical(number: 99, character: '白', strokes: 5, nameJa: 'しろ', nameEn: 'white', position: 'top/left'),
    KangxiRadical(number: 100, character: '皮', strokes: 5, nameJa: 'かわ', nameEn: 'skin', position: 'left'),
    KangxiRadical(number: 101, character: '皿', strokes: 5, nameJa: 'さら', nameEn: 'dish', position: 'bottom'),
    KangxiRadical(number: 102, character: '目', strokes: 5, nameJa: 'め', nameEn: 'eye', position: 'left/bottom'),
    KangxiRadical(number: 103, character: '矛', strokes: 5, nameJa: 'ほこ', nameEn: 'spear', position: 'left'),
    KangxiRadical(number: 104, character: '矢', strokes: 5, nameJa: 'や', nameEn: 'arrow', position: 'left'),
    KangxiRadical(number: 105, character: '石', strokes: 5, nameJa: 'いし', nameEn: 'stone', position: 'left/bottom'),
    KangxiRadical(number: 106, character: '示', strokes: 5, nameJa: 'しめす', nameEn: 'spirit', position: 'left/bottom', variants: ['礻']),
    KangxiRadical(number: 107, character: '禸', strokes: 5, nameJa: 'じゅう', nameEn: 'track', position: 'bottom'),
    KangxiRadical(number: 108, character: '禾', strokes: 5, nameJa: 'のぎ', nameEn: 'grain', position: 'left'),
    KangxiRadical(number: 109, character: '穴', strokes: 5, nameJa: 'あな', nameEn: 'cave', position: 'top'),
    KangxiRadical(number: 110, character: '立', strokes: 5, nameJa: 'たつ', nameEn: 'stand', position: 'left/top'),
    KangxiRadical(number: 111, character: '竹', strokes: 6, nameJa: 'たけ', nameEn: 'bamboo', position: 'top', variants: ['⺮']),
    KangxiRadical(number: 112, character: '米', strokes: 6, nameJa: 'こめ', nameEn: 'rice', position: 'left/bottom'),
    KangxiRadical(number: 113, character: '糸', strokes: 6, nameJa: 'いと', nameEn: 'silk', position: 'left', variants: ['纟', '糹']),
    KangxiRadical(number: 114, character: '缶', strokes: 6, nameJa: 'ほとぎ', nameEn: 'can', position: 'left'),
    KangxiRadical(number: 115, character: '网', strokes: 6, nameJa: 'あみがしら', nameEn: 'net', position: 'top', variants: ['罒', '罓', '罖']),
    KangxiRadical(number: 116, character: '羊', strokes: 6, nameJa: 'ひつじ', nameEn: 'sheep', position: 'left/top', variants: ['⺷']),
    KangxiRadical(number: 117, character: '羽', strokes: 6, nameJa: 'はね', nameEn: 'feather', position: 'left/right', variants: ['⺠']),
    KangxiRadical(number: 118, character: '老', strokes: 6, nameJa: 'おい', nameEn: 'old', position: 'top', variants: ['耂']),
    KangxiRadical(number: 119, character: '而', strokes: 6, nameJa: 'しきにょう', nameEn: 'and', position: 'various'),
    KangxiRadical(number: 120, character: '耒', strokes: 6, nameJa: 'すき', nameEn: 'plow', position: 'left'),
    KangxiRadical(number: 121, character: '耳', strokes: 6, nameJa: 'みみ', nameEn: 'ear', position: 'left'),
    KangxiRadical(number: 122, character: '聿', strokes: 6, nameJa: 'ふで', nameEn: 'brush', position: 'various', variants: ['肀']),
    KangxiRadical(number: 123, character: '肉', strokes: 6, nameJa: 'にく', nameEn: 'meat', position: 'various', variants: ['⺼']),
    KangxiRadical(number: 124, character: '臣', strokes: 6, nameJa: 'しん', nameEn: 'minister', position: 'left'),
    KangxiRadical(number: 125, character: '自', strokes: 6, nameJa: 'みずから', nameEn: 'self', position: 'various'),
    KangxiRadical(number: 126, character: '至', strokes: 6, nameJa: 'いたる', nameEn: 'arrive', position: 'various'),
    KangxiRadical(number: 127, character: '臼', strokes: 6, nameJa: 'うす', nameEn: 'mortar', position: 'various'),
    KangxiRadical(number: 128, character: '舌', strokes: 6, nameJa: 'した', nameEn: 'tongue', position: 'left'),
    KangxiRadical(number: 129, character: '舛', strokes: 6, nameJa: 'まいあし', nameEn: 'oppose', position: 'right/bottom'),
    KangxiRadical(number: 130, character: '舟', strokes: 6, nameJa: 'ふね', nameEn: 'boat', position: 'left'),
    KangxiRadical(number: 131, character: '艮', strokes: 6, nameJa: 'こん', nameEn: 'stopping', position: 'right'),
    KangxiRadical(number: 132, character: '色', strokes: 6, nameJa: 'いろ', nameEn: 'color', position: 'various'),
    KangxiRadical(number: 133, character: '艸', strokes: 6, nameJa: 'くさ', nameEn: 'grass', position: 'top', variants: ['艹', '⺾', '⺿']),
    KangxiRadical(number: 134, character: '虍', strokes: 6, nameJa: 'とらがしら', nameEn: 'tiger', position: 'top'),
    KangxiRadical(number: 135, character: '虫', strokes: 6, nameJa: 'むし', nameEn: 'insect', position: 'left/bottom'),
    KangxiRadical(number: 136, character: '血', strokes: 6, nameJa: 'ち', nameEn: 'blood', position: 'various'),
    KangxiRadical(number: 137, character: '行', strokes: 6, nameJa: 'ゆく', nameEn: 'go/act', position: 'around'),
    KangxiRadical(number: 138, character: '衣', strokes: 6, nameJa: 'ころも', nameEn: 'clothes', position: 'left/bottom', variants: ['衤']),
    KangxiRadical(number: 139, character: '襾', strokes: 6, nameJa: 'にし', nameEn: 'west', position: 'top', variants: ['西', '覀']),
    KangxiRadical(number: 140, character: '見', strokes: 7, nameJa: 'みる', nameEn: 'see', position: 'right/bottom', variants: ['见']),
    KangxiRadical(number: 141, character: '角', strokes: 7, nameJa: 'つの', nameEn: 'horn', position: 'various'),
    KangxiRadical(number: 142, character: '言', strokes: 7, nameJa: 'ことば', nameEn: 'speech', position: 'left', variants: ['訁']),
    KangxiRadical(number: 143, character: '谷', strokes: 7, nameJa: 'たに', nameEn: 'valley', position: 'various'),
    KangxiRadical(number: 144, character: '豆', strokes: 7, nameJa: 'まめ', nameEn: 'bean', position: 'various'),
    KangxiRadical(number: 145, character: '豕', strokes: 7, nameJa: 'いのこ', nameEn: 'pig', position: 'various'),
    KangxiRadical(number: 146, character: '豸', strokes: 7, nameJa: 'けもの', nameEn: 'badger', position: 'left'),
    KangxiRadical(number: 147, character: '貝', strokes: 7, nameJa: 'かい', nameEn: 'shell', position: 'left/bottom', variants: ['贝']),
    KangxiRadical(number: 148, character: '赤', strokes: 7, nameJa: 'あか', nameEn: 'red', position: 'various'),
    KangxiRadical(number: 149, character: '走', strokes: 7, nameJa: 'はしる', nameEn: 'run', position: 'left/bottom'),
    KangxiRadical(number: 150, character: '足', strokes: 7, nameJa: 'あし', nameEn: 'foot', position: 'left', variants: ['⻊']),
    KangxiRadical(number: 151, character: '身', strokes: 7, nameJa: 'み', nameEn: 'body', position: 'left'),
    KangxiRadical(number: 152, character: '車', strokes: 7, nameJa: 'くるま', nameEn: 'car', position: 'left', variants: ['车']),
    KangxiRadical(number: 153, character: '辛', strokes: 7, nameJa: 'からい', nameEn: 'bitter', position: 'various'),
    KangxiRadical(number: 154, character: '辰', strokes: 7, nameJa: 'たつ', nameEn: 'morning', position: 'various'),
    KangxiRadical(number: 155, character: '辵', strokes: 7, nameJa: 'しんにょう', nameEn: 'walk', position: 'around', variants: ['辶', '⻍']),
    KangxiRadical(number: 156, character: '邑', strokes: 7, nameJa: 'むら', nameEn: 'city', position: 'right', variants: ['阝']),
    KangxiRadical(number: 157, character: '酉', strokes: 7, nameJa: 'とり', nameEn: 'wine', position: 'left'),
    KangxiRadical(number: 158, character: '釆', strokes: 7, nameJa: 'のごめ', nameEn: 'distinguish', position: 'various'),
    KangxiRadical(number: 159, character: '里', strokes: 7, nameJa: 'さと', nameEn: 'village', position: 'various'),
    KangxiRadical(number: 160, character: '金', strokes: 8, nameJa: 'かね', nameEn: 'gold/metal', position: 'left', variants: ['釒', '钅']),
    KangxiRadical(number: 161, character: '長', strokes: 8, nameJa: 'ながい', nameEn: 'long', position: 'various', variants: ['镸']),
    KangxiRadical(number: 162, character: '門', strokes: 8, nameJa: 'もん', nameEn: 'gate', position: 'around', variants: ['门']),
    KangxiRadical(number: 163, character: '阜', strokes: 8, nameJa: 'ふおか', nameEn: 'mound', position: 'left', variants: ['阝']),
    KangxiRadical(number: 164, character: '隶', strokes: 8, nameJa: 'れい', nameEn: 'slave', position: 'various'),
    KangxiRadical(number: 165, character: '隹', strokes: 8, nameJa: 'ふとり', nameEn: 'short-tailed bird', position: 'right'),
    KangxiRadical(number: 166, character: '雨', strokes: 8, nameJa: 'あめ', nameEn: 'rain', position: 'top'),
    KangxiRadical(number: 167, character: '靑', strokes: 8, nameJa: 'あお', nameEn: 'blue/green', position: 'various', variants: ['青']),
    KangxiRadical(number: 168, character: '非', strokes: 8, nameJa: 'あらず', nameEn: 'not', position: 'various'),
    KangxiRadical(number: 169, character: '面', strokes: 9, nameJa: 'めん', nameEn: 'face', position: 'various'),
    KangxiRadical(number: 170, character: '革', strokes: 9, nameJa: 'かわ', nameEn: 'leather', position: 'various'),
    KangxiRadical(number: 171, character: '韋', strokes: 9, nameJa: 'なめしがわ', nameEn: 'tanned leather', position: 'various', variants: ['韦']),
    KangxiRadical(number: 172, character: '韭', strokes: 9, nameJa: 'にら', nameEn: 'leek', position: 'various'),
    KangxiRadical(number: 173, character: '音', strokes: 9, nameJa: 'おと', nameEn: 'sound', position: 'various'),
    KangxiRadical(number: 174, character: '頁', strokes: 9, nameJa: 'おおがい', nameEn: 'head', position: 'right', variants: ['页']),
    KangxiRadical(number: 175, character: '風', strokes: 9, nameJa: 'かぜ', nameEn: 'wind', position: 'various', variants: ['风']),
    KangxiRadical(number: 176, character: '飛', strokes: 9, nameJa: 'とぶ', nameEn: 'fly', position: 'various', variants: ['飞']),
    KangxiRadical(number: 177, character: '食', strokes: 9, nameJa: 'たべる', nameEn: 'eat/food', position: 'left/bottom', variants: ['饣', '飠']),
    KangxiRadical(number: 178, character: '首', strokes: 9, nameJa: 'くび', nameEn: 'head/neck', position: 'various'),
    KangxiRadical(number: 179, character: '香', strokes: 9, nameJa: 'かおる', nameEn: 'fragrant', position: 'various'),
    KangxiRadical(number: 180, character: '馬', strokes: 10, nameJa: 'うま', nameEn: 'horse', position: 'left/bottom', variants: ['马']),
    KangxiRadical(number: 181, character: '骨', strokes: 10, nameJa: 'ほね', nameEn: 'bone', position: 'various'),
    KangxiRadical(number: 182, character: '高', strokes: 10, nameJa: 'たかい', nameEn: 'tall', position: 'various', variants: ['髙']),
    KangxiRadical(number: 183, character: '髟', strokes: 10, nameJa: 'かみがしら', nameEn: 'hair', position: 'top'),
    KangxiRadical(number: 184, character: '鬥', strokes: 10, nameJa: 'たたかう', nameEn: 'fight', position: 'around', variants: ['斗']),
    KangxiRadical(number: 185, character: '鬯', strokes: 10, nameJa: 'ちょう', nameEn: 'sacrifice', position: 'various'),
    KangxiRadical(number: 186, character: '鬲', strokes: 10, nameJa: 'れき', nameEn: 'cauldron', position: 'various'),
    KangxiRadical(number: 187, character: '鬼', strokes: 10, nameJa: 'おに', nameEn: 'ghost', position: 'various', variants: ['⿁']),
    KangxiRadical(number: 188, character: '魚', strokes: 11, nameJa: 'さかな', nameEn: 'fish', position: 'left/bottom', variants: ['鱼']),
    KangxiRadical(number: 189, character: '鳥', strokes: 11, nameJa: 'とり', nameEn: 'bird', position: 'right', variants: ['鸟']),
    KangxiRadical(number: 190, character: '鹵', strokes: 11, nameJa: 'ろ', nameEn: 'salt', position: 'various', variants: ['卤']),
    KangxiRadical(number: 191, character: '鹿', strokes: 11, nameJa: 'しか', nameEn: 'deer', position: 'various'),
    KangxiRadical(number: 192, character: '麥', strokes: 11, nameJa: 'ばく', nameEn: 'wheat', position: 'various', variants: ['麦']),
    KangxiRadical(number: 193, character: '麻', strokes: 11, nameJa: 'あさ', nameEn: 'hemp', position: 'top'),
    KangxiRadical(number: 194, character: '黃', strokes: 12, nameJa: 'き', nameEn: 'yellow', position: 'various', variants: ['黄']),
    KangxiRadical(number: 195, character: '黍', strokes: 12, nameJa: 'きび', nameEn: 'millet', position: 'various'),
    KangxiRadical(number: 196, character: '黑', strokes: 12, nameJa: 'くろ', nameEn: 'black', position: 'various', variants: ['黑']),
    KangxiRadical(number: 197, character: '黹', strokes: 12, nameJa: 'ち', nameEn: 'embroidery', position: 'various'),
    KangxiRadical(number: 198, character: '黽', strokes: 13, nameJa: 'べん', nameEn: 'frog', position: 'various', variants: ['黾']),
    KangxiRadical(number: 199, character: '鼎', strokes: 13, nameJa: 'かなえ', nameEn: 'cauldron', position: 'various'),
    KangxiRadical(number: 200, character: '鼓', strokes: 13, nameJa: 'つづみ', nameEn: 'drum', position: 'left'),
    KangxiRadical(number: 201, character: '鼠', strokes: 13, nameJa: 'ねずみ', nameEn: 'rat', position: 'left'),
    KangxiRadical(number: 202, character: '鼻', strokes: 14, nameJa: 'はな', nameEn: 'nose', position: 'various'),
    KangxiRadical(number: 203, character: '齊', strokes: 14, nameJa: 'せい', nameEn: 'even', position: 'various', variants: ['齐']),
    KangxiRadical(number: 204, character: '齒', strokes: 15, nameJa: 'は', nameEn: 'tooth', position: 'various', variants: ['齿']),
    KangxiRadical(number: 205, character: '龍', strokes: 16, nameJa: 'りゅう', nameEn: 'dragon', position: 'various', variants: ['龙']),
    KangxiRadical(number: 206, character: '龜', strokes: 16, nameJa: 'かめ', nameEn: 'turtle', position: 'various', variants: ['龟']),
    KangxiRadical(number: 207, character: '龠', strokes: 17, nameJa: 'やく', nameEn: 'flute', position: 'various'),
  ];

  static Map<int, List<KangxiRadical>> get byStrokeCount {
    final map = <int, List<KangxiRadical>>{};
    for (final r in all) {
      map.putIfAbsent(r.strokes, () => []).add(r);
    }
    return map..forEach((k, v) {
      v.sort((a, b) => a.number.compareTo(b.number));
    });
  }

  static List<int> get strokeCounts {
    final set = <int>{};
    for (final r in all) {
      set.add(r.strokes);
    }
    return set.toList()..sort();
  }

  static KangxiRadical? findByNumber(int number) {
    for (final r in all) {
      if (r.number == number) return r;
    }
    return null;
  }

  static List<KangxiRadical> searchByName(String query) {
    final q = query.toLowerCase();
    return all.where((r) =>
      r.nameEn.toLowerCase().contains(q) ||
      r.nameJa.contains(q) ||
      r.character == query
    ).toList();
  }
}
