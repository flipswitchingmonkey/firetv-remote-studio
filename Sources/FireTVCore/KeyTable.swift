import Foundation

/// macOS virtual key codes (ANSI layout) for the key palette.
public enum KeyTable {
    public struct Entry: Hashable, Identifiable { public let name: String; public let code: UInt16; public var id: String { name } }

    public static let letters: [Entry] = [
        ("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),
        ("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6)
    ].map { Entry(name: $0.0, code: $0.1) }

    public static let digits: [Entry] = [("1",18),("2",19),("3",20),("4",21),("5",23),("6",22),("7",26),("8",28),("9",25),("0",29)]
        .map { Entry(name: $0.0, code: $0.1) }

    public static let symbols: [Entry] = [("-",27),("=",24),("[",33),("]",30),("\\",42),(";",41),("'",39),(",",43),(".",47),("/",44),("`",50)]
        .map { Entry(name: $0.0, code: $0.1) }

    public static let function: [Entry] = [("F1",122),("F2",120),("F3",99),("F4",118),("F5",96),("F6",97),("F7",98),("F8",100),
        ("F9",101),("F10",109),("F11",103),("F12",111),("F13",105),("F14",107),("F15",113),("F16",106),("F17",64),("F18",79),("F19",80)]
        .map { Entry(name: $0.0, code: $0.1) }

    public static let navigation: [Entry] = [("Esc",53),("Tab",48),("Space",49),("Return",36),("Delete",51),("Fwd Del",117),
        ("Home",115),("End",119),("PgUp",116),("PgDn",121),("←",123),("→",124),("↓",125),("↑",126),("Caps",57),("Help",114)]
        .map { Entry(name: $0.0, code: $0.1) }

    public static let all: [Entry] = letters + digits + symbols + function + navigation
}
