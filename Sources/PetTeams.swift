import Foundation

extension World {
    func petID(_ side:Species)->String {side == .roach ? leftPetID : rightPetID}
    func petName(_ side:Species)->String {side == .roach ? leftPetName : rightPetName}
    func teamName(_ side:Species)->String {(side == .roach ? "左队 · " : "右队 · ")+petName(side)}
    func upright(_ side:Species)->Bool {!["roach","ant","rat"].contains(petID(side))}
    func petText(_ text:String)->String {
        if leftPetID=="roach" && rightPetID=="ant" {return text}
        var value=text
        for word in ["蟑螂帮","巨型蟑螂","小蟑螂","蟑螂","厚背成蟑","成蟑"] {value=value.replacingOccurrences(of:word,with:"{LEFT_TEAM}")}
        for word in ["蚂蚁军团","巨型蚂蚁","小蚂蚁","蚂蚁","巨颚兵蚁","小工蚁","幼蚁","成蚁"] {value=value.replacingOccurrences(of:word,with:"{RIGHT_TEAM}")}
        return value.replacingOccurrences(of:"{LEFT_TEAM}",with:teamName(.roach)).replacingOccurrences(of:"{RIGHT_TEAM}",with:teamName(.ant))
    }
    func petMorphTitle(_ b:Bug)->String {
        if petID(b.species)==b.species.rawValue {return b.morphTitle}
        return ["初生","幼小","成年","强壮","巨型"][b.morph]+petName(b.species)
    }
}
