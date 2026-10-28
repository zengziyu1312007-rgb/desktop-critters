import Foundation
struct SprayCloud {var p:V;var age:Double=0}
extension World {
    func spray(_ p:V) {
        guard interactive,!paused,sprayCooldown<=0,mode != .result else {return}
        sprayCooldown=0.22;sprays.append(SprayCloud(p:p));if sprays.count>8 {sprays.removeFirst(sprays.count-8)}
        let count=poisonBugs(at:p)
        say(count==0 ? "喷过了，雾里没有虫。" : "喷倒\(count)只，按4用扫把清理。",force:true)
    }
    @discardableResult func poisonBugs(at p:V)->Int {
        let victims=bugs.filter{$0.p.distance(p)<90+radius($0)*0.45}
        let ids=Set(victims.map{$0.id})
        for var b in victims {
            if b.cargo>0 {_ = addFood(b.p,portions:b.cargo,announce:false)}
            b.cargo=0;b.flight=nil;b.layTime=0;b.speed=0;b.fightTime=0;b.opponentID=nil;b.fightTarget=nil
            corpses.append(Corpse(bug:b));spillJuice(b,crushed:false)
        }
        bugs.removeAll{ids.contains($0.id)}
        if let held=grabbedID,ids.contains(held) {grabbedID=nil}
        if corpses.count>160 {archivedCorpses += corpses.count-160;corpses.removeFirst(corpses.count-160)}
        if !victims.isEmpty {record("杀虫剂：喷倒\(victims.count)只虫，尸体留待清扫")}
        return victims.count
    }
}
