import Foundation

extension InvaderKind {
    var baseHealth:Double {[95,150,115,190,210][Self.allCases.firstIndex(of:self)!]}
    var speed:Double {[60,60,94,66,108][Self.allCases.firstIndex(of:self)!]}
    var cadence:Double {[2.3,1.8,0.72,2.6,1.4][Self.allCases.firstIndex(of:self)!]}
    var damage:Double {[1.4,2,1.1,4.8,2.4][Self.allCases.firstIndex(of:self)!]}
    var reach:Double {self == .snake ? 105 : (self == .rat ? 82 : 64)}
    var raider:Bool {self == .beetle || self == .rat}
    var introduction:String {
        switch self {
        case .spider:return "蜘蛛来了，会吐丝缠住虫群。"
        case .beetle:return "甲虫来了，正冲向食物。"
        case .centipede:return "蜈蚣贴地游走，正在连续追咬。"
        case .snake:return "蛇盘住了，下一下会突然扑咬。"
        case .rat:return "老鼠来抢粮，虫群要被冲散了。"
        }
    }
}
extension World {
    func stepVisitors(_ dt:Double) {
        invasionTimer -= dt
        if invasionTimer<=0 && bugs.count>=30 {_ = summonInvader()}
        for n in invaders.indices where !invaders[n].dead {
            var v=invaders[n];v.age += dt;v.cooldown -= dt
            if v.age>38 {v.p=v.p+(V(x:field.maxX+180,y:field.minY-180)-v.p).unit*(dt*160);invaders[n]=v;continue}
            let targets=bugs.filter{$0.flight == nil && $0.id != grabbedID}.sorted{$0.p.distance(v.p)<$1.p.distance(v.p)}
            var goal=targets.first?.p ?? V(x:field.midX,y:field.midY)
            if v.kind.raider,let food=foods.filter({$0.portions>0}).min(by:{$0.p.distance(v.p)<$1.p.distance(v.p)}) {goal=food.p}
            let d=goal-v.p
            v.angle=atan2(d.y,d.x);v.phase += dt*(v.kind == .centipede ? 18 : 10)
            let winding=v.kind == .centipede || v.kind == .snake
            let direction=(d.unit+(winding ? V(x:-d.unit.y,y:d.unit.x)*sin(v.phase*0.45)*0.55 : .zero)).unit
            let lunging=v.cooldown<0.4 && (v.kind == .snake || v.kind == .beetle)
            let speed=v.kind == .snake && v.cooldown>0.7 && d.length<220 ? 12 : (lunging ? 225 : v.kind.speed)
            if d.length>45 {v.p=safe(v.p+direction*dt*speed)}
            if v.cooldown<=0 {
                var strikes=0
                for subject in targets {
                    guard let i=bugs.firstIndex(where:{$0.id==subject.id}),bugs[i].p.distance(v.p)<radius(bugs[i])+v.kind.reach+26 else {continue}
                    let range=bugs[i].p.distance(v.p)
                    let limit=v.kind == .snake ? 1 : (v.kind == .centipede ? 2 : 5)
                    if range<radius(bugs[i])+v.kind.reach && strikes<limit {
                        bugs[i].health -= v.kind.damage;bugs[i].hitTime=0.3
                        if v.kind == .spider {bugs[i].webTime=2.8}
                        else {bugs[i].p=safeBug(bugs[i].p+(bugs[i].p-v.p).unit*(v.kind == .rat ? 48 : (v.kind == .snake ? 30 : 15)),bugs[i])}
                        let style:AttackStyle=v.kind == .spider ? .web : (v.kind == .snake ? .pincer : (v.kind == .centipede ? .bite : .ram))
                        if fights.count<64 {fights.append(FightEffect(attacker:v.id,defender:bugs[i].id,from:v.p,to:subject.p,swarm:false,heavy:true,style:style,size:v.kind == .rat ? 2.5 : 1.8))}
                        strikes += 1
                    }
                    if bugs[i].adult {
                        v.health -= 1.8*(1+bugs[i].bulkValue*7);bugs[i].fightTime=0.6;bugs[i].fightTarget=v.p
                        if fights.count<64 {fights.append(FightEffect(attacker:bugs[i].id,defender:v.id,from:bugs[i].p,to:v.p,swarm:false,heavy:bugs[i].bulkValue>0.4,style:bugs[i].bulkValue>0.4 ? .ram : .pincer,size:1+bugs[i].bulkValue*2))}
                    }
                }
                if v.kind.raider,let f=foods.indices.first(where:{foods[$0].portions>0 && foods[$0].p.distance(v.p)<foodRadius(foods[$0])+60}) {
                    let taken=min(v.kind == .rat ? 48 : 24,foods[f].portions);foods[f].portions -= taken;v.stolen += taken
                }
                v.cooldown=v.kind.cadence
                if v.dead {record("外敌被击退：\(v.kind.title)倒下，残骸留在桌面")}
            }
            invaders[n]=v
        }
        for v in invaders where !v.dead && v.age>42 {record("外敌撤离：\(v.kind.title)离开，抢走\(v.stolen)份口粮")}
        invaders.removeAll{!$0.dead && $0.age>42}
        let dead=bugs.filter{$0.health<=0}
        if !dead.isEmpty {
            ensureDay()
            for var b in dead {
                if b.cargo>0 {_ = addFood(b.p,portions:b.cargo,announce:false)}
                b.cargo=0;b.flight=nil;b.fightTime=0;corpses.append(Corpse(bug:b));spillJuice(b,crushed:false)
                if b.species == .roach {reports[reports.count-1].roachLost += 1}else{reports[reports.count-1].antLost += 1}
            }
            combatDeaths += dead.count;let ids=Set(dead.map{$0.id});bugs.removeAll{ids.contains($0.id)}
            record("外敌袭击造成\(dead.count)只伤亡")
            if corpses.count>160 {archivedCorpses += corpses.count-160;corpses.removeFirst(corpses.count-160)}
        }
    }
}
