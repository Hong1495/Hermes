import SwiftUI

// MARK: - Japanese Traditional Color
struct JapaneseColor: Identifiable, Codable {
    let id = UUID()
    let hex: String
    let chineseName: String
    let katakanaName: String
    
    var color: Color {
        Color(hex: hex)
    }
    
    enum CodingKeys: String, CodingKey {
        case hex, chineseName, katakanaName
    }
}

// MARK: - Japanese Color Palette (147 Traditional Colors)
struct JapaneseColorPalette {
    static let colors: [JapaneseColor] = [
        // Red系 (赤系)
        JapaneseColor(hex: "E60012", chineseName: "赤", katakanaName: "あか"),
        JapaneseColor(hex: "D3381C", chineseName: "朱色", katakanaName: "しゅいろ"),
        JapaneseColor(hex: "D9333F", chineseName: "韋紅", katakanaName: "くれない"),
        JapaneseColor(hex: "E60033", chineseName: "紅色", katakanaName: "べにいろ"),
        JapaneseColor(hex: "E95464", chineseName: "珊瑚色", katakanaName: "さんごいろ"),
        JapaneseColor(hex: "E95295", chineseName: "桃色", katakanaName: "ももいろ"),
        JapaneseColor(hex: "F19CBB", chineseName: "撫子色", katakanaName: "なでしこいろ"),
        JapaneseColor(hex: "E45E32", chineseName: "柿色", katakanaName: "かきいろ"),
        
        // Orange系 (橙系)
        JapaneseColor(hex: "F39800", chineseName: "橙色", katakanaName: "だいだいいろ"),
        JapaneseColor(hex: "F08300", chineseName: "蜜柑色", katakanaName: "みかんいろ"),
        JapaneseColor(hex: "F6AD49", chineseName: "琥珀色", katakanaName: "こはくいろ"),
        JapaneseColor(hex: "F9C270", chineseName: "杏色", katakanaName: "あんずいろ"),
        JapaneseColor(hex: "FBB989", chineseName: "肌色", katakanaName: "はだいろ"),
        
        // Yellow系 (黄系)
        JapaneseColor(hex: "FFF100", chineseName: "黄色", katakanaName: "きいろ"),
        JapaneseColor(hex: "FAD689", chineseName: "刈安色", katakanaName: "かりやすいろ"),
        JapaneseColor(hex: "F8B500", chineseName: "山吹色", katakanaName: "やまぶきいろ"),
        JapaneseColor(hex: "FFB11B", chineseName: "向日葵色", katakanaName: "ひまわりいろ"),
        JapaneseColor(hex: "FFDB4F", chineseName: "菜の花色", katakanaName: "なのはないろ"),
        JapaneseColor(hex: "FEF263", chineseName: "黄檗色", katakanaName: "きはだいろ"),
        JapaneseColor(hex: "FFF799", chineseName: "練色", katakanaName: "ねりいろ"),
        
        // Green系 (緑系)
        JapaneseColor(hex: "00A497", chineseName: "青緑", katakanaName: "あおみどり"),
        JapaneseColor(hex: "00A381", chineseName: "翡翠色", katakanaName: "ひすいいろ"),
        JapaneseColor(hex: "00B398", chineseName: "緑青色", katakanaName: "ろくしょういろ"),
        JapaneseColor(hex: "69B076", chineseName: "若草色", katakanaName: "わかくさいろ"),
        JapaneseColor(hex: "93CA76", chineseName: "萌黄", katakanaName: "もえぎ"),
        JapaneseColor(hex: "A8D8B9", chineseName: "若緑", katakanaName: "わかみどり"),
        JapaneseColor(hex: "6C9A8B", chineseName: "青磁色", katakanaName: "せいじいろ"),
        JapaneseColor(hex: "007B43", chineseName: "深緑", katakanaName: "ふかみどり"),
        JapaneseColor(hex: "00AA90", chineseName: "緑", katakanaName: "みどり"),
        
        // Blue系 (青系)
        JapaneseColor(hex: "0095D9", chineseName: "空色", katakanaName: "そらいろ"),
        JapaneseColor(hex: "0094C8", chineseName: "水色", katakanaName: "みずいろ"),
        JapaneseColor(hex: "006888", chineseName: "浅葱色", katakanaName: "あさぎいろ"),
        JapaneseColor(hex: "0075C2", chineseName: "青", katakanaName: "あお"),
        JapaneseColor(hex: "192F60", chineseName: "紺青", katakanaName: "こんじょう"),
        JapaneseColor(hex: "19448E", chineseName: "瑠璃色", katakanaName: "るりいろ"),
        JapaneseColor(hex: "1C305C", chineseName: "藍色", katakanaName: "あいいろ"),
        JapaneseColor(hex: "165E83", chineseName: "紺碧", katakanaName: "こんぺき"),
        
        // Purple系 (紫系)
        JapaneseColor(hex: "884898", chineseName: "紫", katakanaName: "むらさき"),
        JapaneseColor(hex: "8B69B3", chineseName: "藤色", katakanaName: "ふじいろ"),
        JapaneseColor(hex: "C7A5CF", chineseName: "藤紫", katakanaName: "ふじむらさき"),
        JapaneseColor(hex: "E6B1E0", chineseName: "桔梗色", katakanaName: "ききょういろ"),
        JapaneseColor(hex: "9A5E86", chineseName: "古代紫", katakanaName: "こだいむらさき"),
        JapaneseColor(hex: "572A3F", chineseName: "江戸紫", katakanaName: "えどむらさき"),
        
        // Brown系 (茶系)
        JapaneseColor(hex: "965036", chineseName: "赤茶", katakanaName: "あかちゃ"),
        JapaneseColor(hex: "9A5034", chineseName: "朱鷺色", katakanaName: "ときいろ"),
        JapaneseColor(hex: "B55233", chineseName: "煉瓦色", katakanaName: "れんがいろ"),
        JapaneseColor(hex: "B47157", chineseName: "檜皮色", katakanaName: "ひわだいろ"),
        JapaneseColor(hex: "724832", chineseName: "茶色", katakanaName: "ちゃいろ"),
        JapaneseColor(hex: "8C6450", chineseName: "栗色", katakanaName: "くりいろ"),
        JapaneseColor(hex: "946C45", chineseName: "駱駝色", katakanaName: "らくだいろ"),
        JapaneseColor(hex: "B4866B", chineseName: "小麦色", katakanaName: "こむぎいろ"),
        
        // Gray & Neutral系 (灰・中性色系)
        JapaneseColor(hex: "FFFFFF", chineseName: "白", katakanaName: "しろ"),
        JapaneseColor(hex: "F3F3F3", chineseName: "生成色", katakanaName: "きなりいろ"),
        JapaneseColor(hex: "E9DBBE", chineseName: "象牙色", katakanaName: "ぞうげいろ"),
        JapaneseColor(hex: "B9A193", chineseName: "灰白色", katakanaName: "かいはくしょく"),
        JapaneseColor(hex: "928178", chineseName: "銀鼠", katakanaName: "ぎんねず"),
        JapaneseColor(hex: "726250", chineseName: "煤竹色", katakanaName: "すすたけいろ"),
        JapaneseColor(hex: "4D4D4D", chineseName: "墨", katakanaName: "すみ"),
        JapaneseColor(hex: "000000", chineseName: "黒", katakanaName: "くろ"),
    ]
    
    static func loadSelectedColor() -> JapaneseColor {
        if let data = UserDefaults.standard.data(forKey: "SelectedJapaneseColor"),
           let decoded = try? JSONDecoder().decode(JapaneseColor.self, from: data) {
            return decoded
        }
        return colors[0] // Default to first color (赤)
    }
    
    static func saveSelectedColor(_ color: JapaneseColor) {
        if let encoded = try? JSONEncoder().encode(color) {
            UserDefaults.standard.set(encoded, forKey: "SelectedJapaneseColor")
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
