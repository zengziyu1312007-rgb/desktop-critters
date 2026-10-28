import Foundation

struct V: Equatable, Codable {
    var x: Double; var y: Double
    static let zero = V(x: 0, y: 0)
    static func + (a: V, b: V) -> V { V(x: a.x+b.x, y: a.y+b.y) }
    static func - (a: V, b: V) -> V { V(x: a.x-b.x, y: a.y-b.y) }
    static func * (a: V, b: Double) -> V { V(x: a.x*b, y: a.y*b) }
    var length: Double { hypot(x,y) }
    var unit: V { length > 0.001 ? self * (1/length) : .zero }
    func distance(_ p: V) -> Double { (self-p).length }
}
struct SeedRandom: Codable {
    var value: UInt64
    mutating func next() -> Double {
        value = value &* 6364136223846793005 &+ 1442695040888963407
        return Double(value >> 11) / Double(UInt64(1) << 53)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + next() * (b-a) }
}
enum Species: String, Codable { case roach, ant }
enum Snack: Int, CaseIterable, Codable {
    case cookie, cake, cheese, strawberry, pizza, banquet
    var title:String { ["饼干","蛋糕","奶酪","草莓","巨型披萨","整块蛋糕"][rawValue] }
    var servings:Int { [24,64,42,32,900,1200][rawValue] }
    var giant:Bool { self == .pizza || self == .banquet }
}
enum AdultRole: String, Codable { case worker, scout, soldier, breeder }
enum PlayMode { case companion, battle, result }
enum Tool: Int { case food = 0, grab = 1, slipper = 2, clean = 3, observe = 4, roachEgg = 5, antEgg = 6, shelter = 8, spray = 9 }
struct Bug: Codable {
    let id: Int
    let species: Species
    var p: V
    var angle: Double = 0
    var phase: Double = 0
    var speed: Double = 0
    var cargo: Int = 0
    var flipped: Double = 0
    var scared: Double = 0
    var cooldown: Double = 0
    var wander: V = .zero
    var wanderTime: Double = 0
    var growth: Double = 1
    var growthMeal: Double = 0
    var breeder = false
    var generation = 1
    var health:Double = 10
    var fightTime:Double = 0
    var opponentID:Int? = nil
    var fightTarget:V? = nil
    var hitTime:Double? = nil
    // Optional additions preserve existing v1 saves.
    var bulk:Double? = nil
    var shownBulk:Double? = nil
    var bitePulse:Double? = nil
    var meals:Int? = nil
    var webTime:Double? = nil
    var attackCooldown:Double? = nil
    var bulkValue:Double { min(1,max(0,bulk ?? 0)) }
    var morph:Int {
        if growth<0.3 {return 0};if growth<1 {return 1}
        return bulkValue<=0.30 ? 2 : (bulkValue<0.78 ? 3 : 4)
    }
    var morphTitle:String {
        (species == .roach ? ["初生若虫","棕背若虫","成蟑","厚背成蟑","巨型蟑螂"] : ["初生幼蚁","小工蚁","成蚁","巨颚兵蚁","巨型蚂蚁"])[morph]
    }
    var role:AdultRole {
        if breeder {return .breeder}
        return id % 7 == 0 ? .soldier : (id % 5 == 0 ? .scout : .worker)
    }
    var toughness:Double { (species == .roach ? 10 : 4) * (role == .soldier ? 1.5 : 1) * (1+bulkValue*6) }
    var bodyScale: Double { (0.38 + 0.62 * growth) * (adult ? (role == .soldier ? 1.18 : (role == .scout ? 0.86 : (role == .breeder ? 1.1 : 1))) : 1) }
    var adult: Bool { growth >= 1 }
    var targetFood: Int? = nil
    var flight:RoachFlight? = nil
    var flightWait:Double? = nil
    var layTime:Double? = nil
}
struct Egg: Codable {
    let id: Int
    let species: Species
    var p: V
    var age: Double = 0
    let hatchTime: Double
    let generation: Int
    var brood: Int = 1
    var layStart:V? = nil
    var layAge:Double? = nil
    var parentID:Int? = nil
    var progress: Double { min(1, age / hatchTime) }
}
struct Corpse: Codable { var bug: Bug }
struct Food: Codable {
    let id: Int
    var p: V
    var portions: Int
    let original: Int
    var angle: Double
    var snack:Snack = .cookie
}
struct Puff: Codable {
    var p: V; var velocity: V; var life: Double; let lifetime: Double; let kind: Int
}
struct JuiceDrop:Codable {
    var offset:V;var radius:Double;let flight:Double
}
struct JuiceSplat:Codable {
    let bugID:Int;var p:V;var radius:Double;let angle:Double;let crushed:Bool
    var age:Double=0
    var drops:[JuiceDrop]
    func hit(_ point:V,padding:Double=0)->Bool {
        let d=point-p,cs=cos(angle),sn=sin(angle)
        let local=V(x:d.x*cs+d.y*sn,y: -d.x*sn+d.y*cs)
        if local.x*local.x/pow(radius*1.9+padding,2)+local.y*local.y/pow(radius*0.85+padding,2)<=1 {return true}
        return drops.contains{local.distance($0.offset)<$0.radius+padding}
    }
    func offset(of drop:JuiceDrop,at time:Double)->V {
        let t=min(1,max(0,time/drop.flight)),travel=1-pow(1-t,2)
        return V(x:drop.offset.x*travel,y:drop.offset.y*travel-radius*2.6*4*t*(1-t))
    }
}
struct Trail: Codable { var p: V; var life: Double }
struct Notice: Codable { var text: String; var time: Double }

enum Relations:String,Codable {
    case hostile, truce, trade
    var title:String { self == .hostile ? "交战" : (self == .truce ? "停火" : "建交通商") }
}
enum AttackStyle:String { case bite, pincer, ram, swarm, web }
enum InvaderKind:String,Codable,CaseIterable { case spider, beetle, centipede, snake, rat
    var title:String {["游猎蜘蛛","抢粮甲虫","游猎蜈蚣","伏击蛇","抢粮老鼠"][Self.allCases.firstIndex(of:self)!]}
}
struct Invader:Codable {
    let id:Int;let kind:InvaderKind
    var p:V;var angle:Double=0;var phase:Double=0
    var health:Double=80;var age:Double=0;var cooldown:Double=1
    var targetID:Int?=nil;var stolen:Int=0
    var dead:Bool {health<=0}
}
struct Sweep {
    let p:V;let bodies:[Bug];let eggs:[Egg];let invaders:[Invader]
    var stains:[JuiceSplat]=[]
    var age:Double=0
    let duration:Double=0.65
}
struct FightEffect {
    let attacker:Int;let defender:Int
    let from:V;let to:V
    let swarm:Bool;let heavy:Bool
    var age:Double=0
    let duration:Double=0.55
    var style:AttackStyle = .bite
    var size:Double = 1
}
struct DailyReport:Codable {
    var day:String
    var roachBorn=0;var antBorn=0;var grown=0
    var roachLost=0;var antLost=0;var swatted=0
    var foodDelivered=0;var trades=0
    var events:[String]=[]
}
struct EcologySave:Codable {
    var version=1
    var width:Double;var height:Double
    var bugs:[Bug];var eggs:[Egg];var foods:[Food];var corpses:[Corpse]
    var archived:Int;var bugSerial:Int;var foodSerial:Int
    var roachFood:Int;var antFood:Int;var roachBirthTimer:Double;var antBirthTimer:Double
    var hatched:Int;var matured:Int;var deaths:Int;var clock:Double
    var relations:Relations;var relationAge:Double;var deathsAtPeace:Int
    var reports:[DailyReport];var random:SeedRandom
    var invaders:[Invader]? = nil
    var splats:[JuiceSplat]? = nil
    var shelters:[EggShelter]? = nil
}

final class World {
    var width: Double; var height: Double
    var random: SeedRandom
    var bugs: [Bug] = []
    var sprays:[SprayCloud]=[]
    var sprayCooldown:Double=0
    var shelters:[EggShelter]=[]
    var flightRandom=SeedRandom(value:0xF17A739)
    var foods: [Food] = []
    var eggs: [Egg] = []
    var corpses: [Corpse] = []
    var splats:[JuiceSplat]=[]
    var archivedCorpses = 0
    var bugSerial = 0
    var roachFood = 8; var antFood = 6
    var roachBirthTimer: Double = 6; var antBirthTimer: Double = 9
    var hatchedCount = 0; var maturedCount = 0
    var relations:Relations = .hostile
    var relationAge:Double = 0
    var deathsAtPeace = 0
    var tradeTimer:Double = 0
    var reports:[DailyReport]=[]
    var dateCheck:Double = 2
    static let dayFormatter:DateFormatter = {let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="yyyy-MM-dd";return f}()
    static let timeFormatter:DateFormatter = {let f=DateFormatter();f.dateFormat="HH:mm";return f}()
    func ensureDay(_ date:Date=Date()) {
        let day=Self.dayFormatter.string(from:date)
        if reports.last?.day != day {reports.append(DailyReport(day:day)); if reports.count>90 {reports.removeFirst(reports.count-90)}}
    }
    func record(_ text:String) {
        ensureDay();let i=reports.count-1
        reports[i].events.append(Self.timeFormatter.string(from:Date())+"  "+text)
        if reports[i].events.count>120 {reports[i].events.removeFirst(reports[i].events.count-120)}
    }
    func setRelations(_ value:Relations,reason:String) {
        guard value != relations else {return}
        relations=value;relationAge=0;deathsAtPeace=combatDeaths
        for i in bugs.indices {bugs[i].fightTime=0;bugs[i].opponentID=nil;bugs[i].fightTarget=nil;bugs[i].hitTime=nil}
        fights.removeAll()
        record("双方"+value.title+"："+reason);say("双方"+value.title+"。"+reason,force:true)
    }
    func diplomacy(_ dt:Double) {
        relationAge += dt;tradeTimer += dt
        if relations == .hostile && relationAge>45 && combatDeaths-deathsAtPeace>=6 {setRelations(.truce,reason:"连番伤亡，暂时休整")}
        else if relations == .truce && relationAge>40 && roachFood>=12 && antFood>=12 {setRelations(.trade,reason:"粮食充足，恢复往来")}
        else if relations != .hostile && relationAge>100 && (roachFood<3 || antFood<3) {setRelations(.hostile,reason:"一方缺粮，停火破裂")}
        if relations == .trade && tradeTimer>15 {
            tradeTimer=0
            let gap=roachFood-antFood
            if abs(gap)>8 {
                let gift=min(4,abs(gap)/2)
                roachFood += gap>0 ? -gift : gift;antFood += gap>0 ? gift : -gift
                ensureDay();reports[reports.count-1].trades += 1
                record("通商互济："+(gap>0 ? "蟑螂帮" : "蚂蚁军团")+"送出 \(gift) 份口粮")
            }
        }
    }
    var reportText:String {
        ensureDay()
        var text="当前关系：\(relations.title)\n蟑螂 \(population(.roach)) · 蚂蚁 \(population(.ant)) · 卵 \(eggs.count) · 尸体 \(corpses.count+archivedCorpses)\n仅记录应用运行时发生的事件；关闭期间不模拟。\n保留最近 90 天，每天最多 120 条事件。\n"
        for day in reports.reversed() {
            text += "\n━━ \(day.day) ━━\n孵化：蟑螂 \(day.roachBorn)，蚂蚁 \(day.antBorn)；成年 \(day.grown)\n交战损失：蟑螂 \(day.roachLost)，蚂蚁 \(day.antLost)；拖鞋拍死 \(day.swatted)\n搬回口粮 \(day.foodDelivered)；通商 \(day.trades) 次\n"
            text += day.events.isEmpty ? "暂无重大事件。\n" : day.events.joined(separator:"\n")+"\n"
        }
        return text
    }
    func saveData() throws -> Data {
        var state=EcologySave(width:width,height:height,bugs:bugs,eggs:eggs,foods:foods,corpses:corpses,archived:archivedCorpses,bugSerial:bugSerial,foodSerial:foodSerial,roachFood:roachFood,antFood:antFood,roachBirthTimer:roachBirthTimer,antBirthTimer:antBirthTimer,hatched:hatchedCount,matured:maturedCount,deaths:combatDeaths,clock:clock,relations:relations,relationAge:relationAge,deathsAtPeace:deathsAtPeace,reports:reports,random:random)
        state.invaders=invaders;state.splats=splats;state.shelters=shelters
        return try JSONEncoder().encode(state)
    }
    func restore(_ data:Data) throws {
        let s=try JSONDecoder().decode(EcologySave.self,from:data)
        let ids=s.bugs.map{$0.id}+s.eggs.map{$0.id}
        guard s.version==1,s.bugs.count<=300,s.eggs.count<=300,s.foods.count<=18,s.corpses.count<=160,
              s.width>0,s.height>0,Set(ids).count==ids.count,ids.allSatisfy({$0<s.bugSerial}),s.reports.count<=90 else {throw NSError(domain:"EcologySave",code:1)}
        guard s.bugs.allSatisfy({($0.bulk ?? 0).isFinite && (0...1).contains($0.bulk ?? 0)}),
              (s.invaders ?? []).count<=8,(s.splats ?? []).count<=96,(s.shelters ?? []).count<=6,(s.shelters ?? []).allSatisfy({$0.p.x.isFinite && $0.p.y.isFinite}),
              (s.splats ?? []).allSatisfy({ j in
                  j.p.x.isFinite && j.p.y.isFinite && j.radius.isFinite && j.radius>0 && j.radius<=240 && j.angle.isFinite && j.age.isFinite && j.age>=0 && j.drops.count<=64 &&
                  j.drops.allSatisfy{$0.offset.x.isFinite && $0.offset.y.isFinite && $0.radius.isFinite && $0.radius>0 && $0.radius<=80 && $0.flight.isFinite && $0.flight>0 && $0.flight<=2}
              }) else {throw NSError(domain:"EcologySave",code:2)}
        let newWidth=width,newHeight=height
        width=s.width;height=s.height;bugs=s.bugs;eggs=s.eggs;foods=s.foods;corpses=s.corpses
        archivedCorpses=s.archived;bugSerial=s.bugSerial;foodSerial=s.foodSerial
        roachFood=s.roachFood;antFood=s.antFood;roachBirthTimer=s.roachBirthTimer;antBirthTimer=s.antBirthTimer
        hatchedCount=s.hatched;maturedCount=s.matured;combatDeaths=s.deaths;clock=s.clock
        relations=s.relations;relationAge=s.relationAge;deathsAtPeace=s.deathsAtPeace;reports=s.reports;random=s.random
        shelters=s.shelters ?? [];invaders=s.invaders ?? [];splats=(s.splats ?? []).map{var j=$0;j.age=max(1,j.age);return j};sweeps=[];fights=[]
        rebalanceGrowth();resize(width:newWidth,height:newHeight);ensureDay()
    }
    var selectedSnack:Snack = .cookie
    var combatTimer:Double = 0
    var fights:[FightEffect]=[]
    var sweeps:[Sweep]=[]
    var sweepAnchor:V? = nil
    var invaders:[Invader]=[]
    var invasionTimer:Double=140
    var invasionSerial:Int=0

    var battleEventTime:Double = -100
    var combatDeaths = 0
    func populationLimit(_ species:Species)->Int { species == .roach ? 60 : 240 }
    var ecologyCount:Int { bugs.count }
    var ecologyLabel:String { "活体 \(bugs.count) · 卵 \(eggs.count) · 冲突死亡 \(combatDeaths)" }
    var ecologyInteractive = false
    var filming = false
    var lifeRate: Double = 1
    var watchedID: Int? = nil
    var field: CGRect {
        guard filming else { return CGRect(x:25,y:35,width:max(100,width-50),height:max(100,height-70)) }
        let h = max(240,min(height-110,(width-410)*16/9))
        return CGRect(x:48,y:65,width:h*9/16,height:h)
    }
    func reserved(_ species: Species) -> Int { population(species) + eggs.filter{$0.species == species}.reduce(0){$0+$1.brood} }
    func toggleFilming() {
        let old = field
        filming.toggle()
        let new = field
        func convert(_ p:V)->V { safe(V(x:new.minX+(p.x-old.minX)/old.width*new.width,y:new.minY+(p.y-old.minY)/old.height*new.height)) }
        for i in bugs.indices { bugs[i].p=convert(bugs[i].p); bugs[i].wander=bugs[i].p; bugs[i].wanderTime=0 }
        for i in eggs.indices { eggs[i].p=convert(eggs[i].p) }
        for i in foods.indices { foods[i].p=convert(foods[i].p) }
        for i in corpses.indices { corpses[i].bug.p=convert(corpses[i].bug.p) }
        for i in splats.indices {splats[i].p=convert(splats[i].p)}
        trails.removeAll(); puffs.removeAll();fights.removeAll()
    }
    func cycleRate() { lifeRate = lifeRate == 1 ? 2 : (lifeRate == 2 ? 4 : 1) }
    func observe(_ p: V) {
        var choices = bugs.map{($0.id,bodyHit($0,p,padding:10) ? 0.0 : $0.p.distance(p))}
        choices += eggs.map{($0.id,$0.p.distance(p))}
        watchedID = choices.filter{$0.1 < 55}.min{$0.1 < $1.1}?.0
    }
    var observation: (V,String)? {
        guard let id=watchedID else { return nil }
        if let e=eggs.first(where:{$0.id==id}) {
            let seconds=Int(ceil(max(0,e.hatchTime-e.age)/lifeRate))
            return (e.p,"第\(e.generation)代 · 约\(seconds)秒孵化 · 余\(e.brood)只")
        }
        if let b=bugs.first(where:{$0.id==id}) {
            let stock=b.species == .roach ? roachFood : antFood
            let phase=b.adult ? "成年" : (stock == 0 ? "缺粮 · 成长暂停" : "成长 \(Int(b.growth*100))%")
            let role=b.role == .soldier ? "兵型" : (b.role == .scout ? "侦察型" : (b.role == .breeder ? "繁殖型" : "搬运型"))
            return (b.p,"第\(b.generation)代 · \(b.morphTitle) · 吃\(b.meals ?? 0)口 · \(role) · \(phase)")
        }
        if let b=corpses.first(where:{$0.bug.id==id})?.bug { return (b.p,"#\(b.id) · 已死亡") }
        return nil
    }
    var interactive: Bool { mode == .battle || (mode == .companion && ecologyInteractive) }
    func population(_ species: Species) -> Int { bugs.filter{$0.species == species}.count }
    func eggCount(_ species: Species) -> Int { eggs.filter{$0.species == species}.count }
    func lifeSummary(_ species: Species) -> String {
        let young = bugs.filter{$0.species == species && !$0.adult}.count
        return "活\(population(species)) · 幼\(young) · 卵\(eggCount(species))"
    }
    var puffs: [Puff] = []
    var trails: [Trail] = []
    var mode: PlayMode = .companion
    var tool: Tool = .food
    var paused = false
    var clock: Double = 0
    var remaining: Double = 150
    var roachScore = 0; var antScore = 0
    var notice = Notice(text: "它们已经入住。开一局，丢块饼干试试。", time: 8)
    var pointer: V? = nil
    var grabbedID: Int? = nil
    var slap: V? = nil
    var slapTime: Double = 0
    var foodSerial = 0
    var autoFoodTime: Double = 0
    var trailTime: Double = 0
    var eventCooldown: Double = 0
    var avoid: CGRect = .zero
    var soundEvent = false
    var roachNest: V { filming ? V(x:field.minX+66,y:field.maxY-62) : V(x:84,y:height-92) }
    var antNest: V { filming ? V(x:field.maxX-66,y:field.minY+75) : V(x:width-84,y:height-92) }
    var resultTitle: String { roachScore == antScore ? "势均力敌，再来一块？" : (roachScore > antScore ? "蟑螂帮，抢饭成功！" : "蚂蚁军团，搬空全场！") }

    init(width: Double, height: Double, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.width = width; self.height = height; random = SeedRandom(value: seed)
        ensureDay()
        populate(battle: false)
    }
    func say(_ text: String, force: Bool = false) {
        if force || eventCooldown <= 0 { notice = Notice(text:text,time:4.5); eventCooldown = 3 }
    }
    func populate(battle: Bool) {
        bugs.removeAll(); foods.removeAll(); trails.removeAll(); puffs.removeAll();fights.removeAll();sweeps=[];invaders=[];invasionTimer=140
        eggs.removeAll(); corpses.removeAll(); splats=[];sprays=[];sprayCooldown=0; archivedCorpses = 0
        roachFood = 120; antFood = 180; roachBirthTimer = 6; antBirthTimer = 5
        combatDeaths=0; combatTimer=0;relations = .hostile;relationAge=0;deathsAtPeace=0
        hatchedCount = 0; maturedCount = 0; watchedID = nil
        for i in 0..<(battle ? 52 : 40) {
            let species: Species = i < (battle ? 10 : 8) ? .roach : .ant
            let nest = species == .roach ? roachNest : antNest
            let p: V
            if species == .ant {
                let j = i-(battle ? 10 : 8)
                let route = V(x:-0.91,y:-0.42)
                p = safe(nest + route*(Double(j)*18+12) + V(x:-route.y,y:route.x)*Double((j%2)*2-1)*9)
            } else { p = safe(nest + V(x: random.range(-45,45), y:random.range(-55,10))) }
            bugs.append(Bug(id:i,species:species,p:p,angle:random.range(-Double.pi,Double.pi),phase:random.range(0,6.28),wander:p))
        }
        bugSerial = bugs.count
        for i in bugs.indices {
            bugs[i].breeder = bugs[i].species == .roach ? i % 2 == 0 : (i == (battle ? 10 : 8) || i == (battle ? 11 : 9))
            bugs[i].health=bugs[i].toughness
            if i % 4 == 3 { bugs[i].growth=0.35 }
        }
        autoFoodTime = 0
        _ = addFood(V(x:width*0.47,y:height*0.57),portions:18,announce:false)
        if filming { foods[0].p = V(x:field.midX,y:field.midY) }
        if !battle {
            _ = addFood(V(x:width*0.32,y:height*0.34),kind:.cake,announce:false)
            _ = addFood(V(x:width*0.68,y:height*0.42),kind:.strawberry,announce:false)
            _ = addFood(V(x:width*0.54,y:height*0.76),kind:.cheese,announce:false)
        }
        if battle {
            _ = addFood(V(x:width*0.28,y:height*0.39),portions:14,announce:false)
            _ = addFood(V(x:width*0.63,y:height*0.72),portions:14,announce:false)
        }
    }
    func startRound() {
        mode = .battle; ecologyInteractive = false; paused = false; roachScore = 0; antScore = 0
        remaining = 150; grabbedID = nil; pointer = nil; tool = .food
        populate(battle:true)
        record("重新开局，双方建立新种群")
        say("往空白处丢块饼干。它们会自己来抢。",force:true)
    }
    func companion() {
        mode = .companion; ecologyInteractive = false; paused = false; grabbedID = nil; pointer = nil
        say("安心工作，鼠标已经可以穿过它们。",force:true)
    }
    func safe(_ p: V) -> V {
        let bounds=field
        let q = V(x:min(max(bounds.minX,p.x),bounds.maxX),y:min(max(bounds.minY,p.y),bounds.maxY))
        // Control UI is an overlay, not a wall: routes may continue underneath it.
        // Input exclusion still lives in AppDelegate, so controls remain clickable.
        return q
    }
    func scale(for b:Bug,animated:Bool=true)->Double {
        let base=b.bodyScale
        let roachCap=min(sqrt(field.width*field.height*0.25/(130*78)),field.width*0.86/130,field.height*0.86/78)
        // Photographic bodies: roach 65 local points; ant 26. Keep maximum ant body length half.
        let cap=b.species == .roach ? roachCap : roachCap*65/26*0.5
        let progress=animated ? min(1,max(0,b.shownBulk ?? b.bulkValue)) : b.bulkValue
        return base*pow(max(1,cap/base),progress)
    }
    func radius(_ b:Bug)->Double { (b.species == .roach ? 29 : 11)*scale(for:b) }
    func safeBug(_ p:V,_ b:Bug)->V {
        let k=scale(for:b),cs=cos(b.angle),sn=sin(b.angle)
        let back=b.species == .roach ? -47.0 : -17.0,front=b.species == .roach ? 95.0 : 21.0,half=b.species == .roach ? 39.0 : 13.0
        let corners=[V(x:back,y:-half),V(x:back,y:half),V(x:front,y:-half),V(x:front,y:half)].map{V(x:($0.x*cs-$0.y*sn)*k,y:($0.x*sn+$0.y*cs)*k)}
        let minX=field.minX-corners.map{$0.x}.min()!,maxX=field.maxX-corners.map{$0.x}.max()!
        let minY=field.minY-corners.map{$0.y}.min()!,maxY=field.maxY-corners.map{$0.y}.max()!
        return V(x:minX<=maxX ? min(max(minX,p.x),maxX) : field.midX,y:minY<=maxY ? min(max(minY,p.y),maxY) : field.midY)
    }
    func bodyHit(_ b:Bug,_ p:V,padding:Double=0,corpse:Bool=false)->Bool {
        let d=p-b.p,cs=cos(b.angle),sn=sin(b.angle),k=scale(for:b)
        let x=d.x*cs+d.y*sn,y = -d.x*sn+d.y*cs
        let rx=(b.species == .roach ? 34.0 : 14.0)*k+padding
        let ry=(b.species == .roach ? 15.0 : 8.0)*k*(corpse ? 0.55 : 1)+padding
        return x*x/(rx*rx)+y*y/(ry*ry)<=1
    }
    func snackScale(_ snack:Snack)->Double {snack.giant ? min(field.width,field.height)*0.42/56 : 1}
    func foodRadius(_ f:Food)->Double { f.original<=5 ? 5 : (f.snack == .pizza ? 23 : 20)*snackScale(f.snack) }
    // Large adults occupy a minority of each camp; only one can reach the final giant stage.
    // Counting excludes the subject, so it can continue growing without surrendering its place.
    func growthCeiling(_ b:Bug)->Double {
        let peers=bugs.filter{$0.species == b.species && $0.id != b.id}
        let largeLimit=max(2,(peers.count+1)/5)
        if b.bulkValue<=0.30 && peers.filter({$0.bulkValue>0.30}).count>=largeLimit {return 0.30}
        return peers.contains{$0.bulkValue>=0.78} ? 0.70 : 1
    }
    func rebalanceGrowth() {
        // Balance older saves without deleting individuals, meals, eggs or their history.
        for species in [Species.roach,.ant] {
            let ranked=bugs.indices.filter{bugs[$0].species == species}.sorted {
                let a=bugs[$0],b=bugs[$1]
                if a.bulkValue != b.bulkValue {return a.bulkValue>b.bulkValue}
                if (a.meals ?? 0) != (b.meals ?? 0) {return (a.meals ?? 0)>(b.meals ?? 0)}
                return a.id<b.id
            }
            let largeLimit=max(2,ranked.count/5)
            for (rank,i) in ranked.enumerated() {
                let cap=rank==0 ? 1.0 : (rank<largeLimit ? 0.70 : 0.30)
                if bugs[i].bulkValue>cap {
                    bugs[i].bulk=cap;bugs[i].shownBulk=cap
                    bugs[i].health=min(bugs[i].health,bugs[i].toughness)
                }
            }
        }
    }
    func biteBug(at index:Int,food:Int) {
        guard bugs.indices.contains(index) else {return}
        var subject=bugs[index];bite(&subject,food:food);bugs[index]=subject
    }
    func bite(_ b:inout Bug,food index:Int) {
        guard b.flight == nil else {return}
        guard foods.indices.contains(index),foods[index].portions>0,b.cooldown<=0 else {return}
        let oldMorph=b.morph,oldHealth=b.toughness,oldGrowth=b.growth
        let giant=foods[index].snack.giant && foods[index].original>5
        let base=b.species == .roach ? 5.0 : 2.0
        let amount=min(foods[index].portions,max(1,Int(base*pow(1+b.bulkValue*7,1.35))))
        foods[index].portions -= amount
        // A real bite consumes nutrition. Small workers carry the remainder home.
        if b.bulkValue<0.42 {b.cargo += max(0,amount-1)}
        let ceiling=max(b.bulkValue,min(giant ? 1 : 0.30,growthCeiling(b)))
        b.bulk=min(ceiling,b.bulkValue+(giant ? 0.23 : 0.075))
        if b.shownBulk == nil {b.shownBulk=0}
        b.growth=min(1,b.growth+0.18);b.meals=(b.meals ?? 0)+1;b.bitePulse=0.55
        b.cooldown=b.bulkValue>=0.42 ? 2.4 : 1.1
        b.health=min(b.toughness,b.health+max(0,b.toughness-oldHealth))
        if oldGrowth<1 && b.adult {maturedCount += 1;ensureDay();reports[reports.count-1].grown += 1}
        if b.morph != oldMorph {record("进食蜕变：\(b.species == .roach ? "蟑螂" : "蚂蚁") #\(b.id) 长成\(b.morphTitle)");say(b.bulkValue>=0.78 ? "\(b.morphTitle)！这一营的巨虫诞生了。" : "\(b.morphTitle)！大餐继续喂给它。",force:true)}
        burst(foods[index].p,kind:0,count:5)
    }
    func spillJuice(_ b:Bug,crushed:Bool) {
        guard b.species == .roach,!splats.contains(where:{$0.bugID==b.id}) else {return}
        let k=scale(for:b),r=min(180,max(5,16*k*(crushed ? 1.4 : 0.8)))
        // Visual randomness is independent of the ecology generator.
        var ink=SeedRandom(value:UInt64(max(0,b.id)) &* 7919 &+ UInt64(max(0,clock*1000)) &+ 71)
        let count=min(64,Int(32+min(28,k*5)))
        var drops:[JuiceDrop]=[]
        for n in 0..<count {
            let angle=ink.range(0,Double.pi*2),reach=r*ink.range(n%4==0 ? 2.4 : 0.85,n%4==0 ? 5 : 3.2)
            drops.append(JuiceDrop(offset:V(x:cos(angle)*reach,y:sin(angle)*reach*0.7),radius:r*ink.range(0.045,0.19),flight:ink.range(0.4,0.82)))
        }
        splats.append(JuiceSplat(bugID:b.id,p:b.p,radius:r,angle:b.angle,crushed:crushed,drops:drops))
        if splats.count>96 {splats.removeFirst(splats.count-96)}
    }
    func sweep(_ p:V) {
        let bodies=corpses.filter{bodyHit($0.bug,p,padding:65,corpse:true)}.map{$0.bug}
        let shells=eggs.filter{$0.p.distance(p)<70}
        let outsiders=invaders.filter{$0.dead && $0.p.distance(p)<120}
        let ids=Set(bodies.map{$0.id}),eggIDs=Set(shells.map{$0.id}),outsiderIDs=Set(outsiders.map{$0.id})
        let stains=splats.filter{ids.contains($0.bugID) || $0.hit(p,padding:65)}
        let stainIDs=Set(stains.map{$0.bugID});splats.removeAll{stainIDs.contains($0.bugID)}
        corpses.removeAll{ids.contains($0.bug.id)};eggs.removeAll{eggIDs.contains($0.id)};invaders.removeAll{outsiderIDs.contains($0.id)}
        if p.distance(V(x:width/2,y:height-50))<70 {archivedCorpses=0}
        sweeps.append(Sweep(p:p,bodies:bodies,eggs:shells,invaders:outsiders,stains:stains))
        if sweeps.count>8 {sweeps.removeFirst(sweeps.count-8)}
        sweepAnchor=p;burst(p,kind:4,count:12)
        say("扫走尸体、汁液和卵。",force:true)
    }
    @discardableResult func summonInvader(_ kind:InvaderKind?=nil)->Bool {
        guard !invaders.contains(where:{!$0.dead}) else {say("外敌还在桌面上。",force:true);return false}
        invasionSerial += 1
        let chosen=kind ?? InvaderKind.allCases[(invasionSerial-1)%InvaderKind.allCases.count]
        let id=(invaders.map{$0.id}.max() ?? 1000000)+1
        let p=V(x:field.midX,y:field.minY+90)
        let strength=1+(bugs.map{$0.bulkValue}.max() ?? 0)*2.5
        invaders.append(Invader(id:id,kind:chosen,p:p,health:chosen.baseHealth*strength))
        if invaders.count>8 {invaders.removeFirst(invaders.count-8)}
        record("外敌来袭：\(chosen.title)闯入桌面，双方各自迎敌")
        say(chosen.introduction,force:true)
        invasionTimer=180;return true
    }
    func updateInvaders(_ dt:Double) {stepVisitors(dt)}
    @discardableResult func addFood(_ p: V, portions: Int? = nil, kind:Snack? = nil, announce: Bool = true) -> Bool {
        guard foods.count < 18 else { if announce { say("桌面够吃啦，等它们搬完一些。",force:true) }; return false }
        foodSerial += 1
        let snack=kind ?? (portions == nil ? selectedSnack : .cookie), amount=max(1,portions ?? snack.servings)
        foods.append(Food(id:foodSerial,p:safe(p),portions:amount,original:amount,angle:random.range(-0.4,0.4),snack:snack))
        burst(p,kind:0,count:7)
        if announce { say("加餐！看看谁先抢到。",force:true) }
        return true
    }
    func burst(_ p: V, kind: Int, count: Int) {
        for _ in 0..<count {
            let a = random.range(0,Double.pi*2), speed = random.range(25,90), life = random.range(0.3,0.7)
            puffs.append(Puff(p:p,velocity:V(x:cos(a)*speed,y:sin(a)*speed),life:life,lifetime:life,kind:kind))
        }
        if puffs.count > 160 { puffs.removeFirst(puffs.count-160) }
    }
    @discardableResult func placeEgg(_ species:Species,at p:V) -> Bool {
        let brood=species == .roach ? 3 : 1
        guard reserved(species)+brood <= populationLimit(species) else {
            say("这一边住满了，等空出名额再放卵。",force:true); return false
        }
        let id=bugSerial; bugSerial += 1
        eggs.append(Egg(id:id,species:species,p:safe(p),hatchTime:species == .roach ? 28 : 22,generation:1,brood:brood))
        watchedID=id
        say(species == .roach ? "放下一枚蟑螂卵鞘，会孵出 3 只。" : "放下一枚蚁卵，等它孵化。",force:true)
        return true
    }
    func press(_ p: V) {
        guard interactive else { return }
        if tool == .shelter {markShelter(p);return}
        if tool == .observe { observe(p); return }
        if tool == .roachEgg { _ = placeEgg(.roach,at:p); return }
        if tool == .antEgg { _ = placeEgg(.ant,at:p); return }
        guard !paused else { return }
        pointer = p
        switch tool {
        case .spray:spray(p)
        case .shelter:markShelter(p)
        case .roachEgg: _ = placeEgg(.roach,at:p)
        case .antEgg: _ = placeEgg(.ant,at:p)
        case .observe: observe(p)
        case .food:
            let subject=bugs.indices.filter{bodyHit(bugs[$0],p,padding:5)}.max{bugs[$0].p.y<bugs[$1].p.y}
            let drop=subject.map{bugs[$0].p+V(x:cos(bugs[$0].angle),y:sin(bugs[$0].angle))*(radius(bugs[$0])+20*snackScale(selectedSnack))} ?? p
            if addFood(drop),let i=subject,bugs[i].flight == nil {biteBug(at:i,food:foods.count-1)}
        case .grab:
            if let b = bugs.filter({bodyHit($0,p,padding:10)}).max(by:{$0.p.y<$1.p.y}) {
                if let i=bugs.firstIndex(where:{$0.id==b.id}) {bugs[i].flight=nil;bugs[i].flightWait=12}
                grabbedID = b.id; say(b.species == .roach ? "逮到了！把它放到另一边试试。" : "轻拿轻放，搬运工也要休息。",force:true)
            } else { say("靠近一只虫子，按住拖走。",force:true) }
        case .slipper: swat(p)
        case .clean: sweep(p)
        }
    }
    func drag(_ p: V) {
        pointer = p
        if tool == .spray {spray(p)}
        if interactive && !paused && tool == .clean,let last=sweepAnchor,last.distance(p)>24 {
            let steps=max(1,Int(ceil(last.distance(p)/24)))
            for n in 1...steps {sweep(last+(p-last)*(Double(n)/Double(steps)))}
        }
        if let id = grabbedID, let i = bugs.firstIndex(where:{$0.id == id}) { bugs[i].p = safeBug(p,bugs[i]); bugs[i].speed = 0 }
    }
    func release() {
        sweepAnchor=nil
        if let id = grabbedID, let i = bugs.firstIndex(where:{$0.id == id}) { bugs[i].scared = 1.8 }
        grabbedID = nil
    }
    func swat(_ p: V) {
        guard slapTime <= 0 else { return }
        slap = p; slapTime = 0.38; soundEvent = true; burst(p,kind:1,count:14)
        let victims = bugs.filter{bodyHit($0,p,padding:50)}
        ensureDay();reports[reports.count-1].swatted += victims.count
        if !victims.isEmpty {record("拖鞋拍死 \(victims.count) 只，尸体留在桌面")}
        for victim in victims {
            if victim.cargo > 0 { _ = addFood(victim.p,portions:victim.cargo,announce:false) }
            var body = victim; body.cargo = 0; body.speed = 0; body.flipped = 0;body.flight=nil
            corpses.append(Corpse(bug:body));spillJuice(body,crushed:true)
            if grabbedID == victim.id { grabbedID = nil }
        }
        let ids = Set(victims.map{$0.id})
        bugs.removeAll{ids.contains($0.id)}
        for i in invaders.indices where !invaders[i].dead && invaders[i].p.distance(p)<100 {invaders[i].health=0;record("拖鞋击倒\(invaders[i].kind.title)")}
        let oldEggs = eggs.count
        eggs.removeAll{$0.p.distance(p)<66}
        for i in bugs.indices where bugs[i].p.distance(p)<250 { bugs[i].scared = 2 }
        _ = scareRoaches(at:p)
        if corpses.count > 160 {
            let excess = corpses.count-160
            archivedCorpses += excess; corpses.removeFirst(excess)
        }
        say(victims.isEmpty && oldEggs == eggs.count ? "没拍着。它们倒是吓了一跳。" : "拍死 \(victims.count) 只 · 碎卵 \(oldEggs-eggs.count) 枚。按 4 清扫。",force:true)
    }
    func lifecycle(_ dt: Double) {
        for i in bugs.indices {bugs[i].layTime=max(0,(bugs[i].layTime ?? 0)-dt)}
        // Eggs are prepaid; surviving eggs can hatch even if the adults are killed.
        for i in eggs.indices {
            let old=eggs[i].layAge ?? 3
            if eggs[i].layAge != nil {eggs[i].layAge=min(3,old+dt)}
            eggs[i].age += max(0,dt-max(0,2.8-old))
        }
        for i in eggs.indices where eggs[i].progress >= 1 {
            let egg=eggs[i]
            let p = hatchPoint(egg)
            var child = Bug(id:bugSerial,species:egg.species,p:p,angle:random.range(-3.14,3.14),wander:p)
            child.growth = 0; child.generation = egg.generation
            child.breeder = egg.species == .roach ? bugSerial % 2 == 0 : bugSerial % 19 == 0
            child.health=child.toughness
            if watchedID == egg.id { watchedID=child.id }
            bugSerial += 1; bugs.append(child); hatchedCount += 1
            ensureDay()
            if child.species == .roach {reports[reports.count-1].roachBorn += 1} else {reports[reports.count-1].antBorn += 1}
            if hatchedCount % 20 == 0 {record("新生命持续孵化，本轮累计 \(hatchedCount) 只")}

            eggs[i].brood -= 1; eggs[i].age=egg.hatchTime-1.0
            burst(p,kind:egg.species == .roach ? 2 : 3,count:5)
            say(egg.species == .roach ? "卵鞘孵化了，里面可能不止一只。" : "小蚂蚁出窝了，搬粮队又添新成员。")
        }
        eggs.removeAll{$0.brood <= 0}
        for i in bugs.indices where !bugs[i].adult {
            let roach = bugs[i].species == .roach
            let stock = roach ? roachFood : antFood
            guard stock > 0 else { continue }
            bugs[i].growthMeal += dt
            if bugs[i].growthMeal >= 12 {
                bugs[i].growthMeal -= 12
                if roach { roachFood -= 1 } else { antFood -= 1 }
            }
            bugs[i].growth = min(1,bugs[i].growth + dt/(roach ? 65 : 50))
            if bugs[i].adult { maturedCount += 1;ensureDay();reports[reports.count-1].grown += 1; say(roach ? "小蟑螂长大了，搬运更有力。" : "一只幼蚁成年了，搬运更有力。") }
        }
        roachBirthTimer -= dt; antBirthTimer -= dt
        for species in [Species.roach, .ant] {
            let roach = species == .roach
            let timer = roach ? roachBirthTimer : antBirthTimer
            let stock = roach ? roachFood : antFood
            let cost = roach ? 4 : 1
            let parents=bugs.filter{$0.species == species && $0.adult && $0.breeder && $0.id != grabbedID && $0.flight == nil && ($0.layTime ?? 0)<=0}
            guard timer <= 0, stock >= cost, !parents.isEmpty else {continue}
            let batch=roach ? min(3,parents.count) : min(8,parents.count*3)
            for n in 0..<batch {
                let available=roach ? roachFood : antFood
                guard available>=cost, reserved(species)+(roach ? 3 : 1)<=populationLimit(species) else {break}
                var parent=parents[n % parents.count]
                if let place=shelters.min(by:{$0.p.distance(parent.p)<$1.p.distance(parent.p)}),place.p.distance(parent.p)<radius(parent)+100 {parent.angle=atan2(parent.p.y-place.p.y,parent.p.x-place.p.x)}
                var e=emittedEgg(parent,id:bugSerial)
                if n>=parents.count {e.p=e.p+V(x:Double(n%3)*4,y:Double(n/3)*3)}
                eggs.append(e)
                if let i=bugs.firstIndex(where:{$0.id==parent.id}) {bugs[i].layTime=2.8;bugs[i].angle=parent.angle}
                bugSerial += 1
                if roach {roachFood -= cost} else {antFood -= cost}
            }
            if roach {roachBirthTimer=16} else {antBirthTimer=8}
            say(roach ? "成蟑停下来，正在从腹部排出卵鞘。" : "蚁后停下来，正在产卵。")
        }
    }
    func resolveCrowding(_ elapsed:Double) {
        guard relations == .hostile else {return}
        var damage:[Int:Double]=[:], knockback:[Int:V]=[:]
        for i in bugs.indices {bugs[i].attackCooldown=max(0,(bugs[i].attackCooldown ?? 0)-elapsed)}
        let snapshot=bugs
        let sizes=Dictionary(uniqueKeysWithValues:snapshot.map{($0.id,radius($0))})
        var pairs:[(Int,Int)]=[]
        for i in snapshot.indices where snapshot[i].adult && snapshot[i].flight == nil && snapshot[i].id != grabbedID {
            let b=snapshot[i]
            let nearby=snapshot.indices.filter{snapshot[$0].id != b.id && snapshot[$0].p.distance(b.p)<max(100,(sizes[b.id] ?? 0)+(sizes[snapshot[$0].id] ?? 0)+55)}
            let enemies=nearby.filter{snapshot[$0].species != b.species && snapshot[$0].flight == nil && snapshot[$0].adult && snapshot[$0].id != grabbedID}
            let locked=enemies.first{snapshot[$0].id==b.opponentID}
            let defending=enemies.first{snapshot[$0].opponentID==b.id}
            let contested=foods.contains{$0.portions>0 && $0.p.distance(b.p)<85+foodRadius($0)+radius(b)}
            guard nearby.count>=7 || contested || locked != nil || defending != nil else {
                bugs[i].opponentID=nil;bugs[i].fightTarget=nil
                bugs[i].health=min(b.toughness,b.health+elapsed*0.3);continue
            }
            guard let enemy=locked ?? defending ?? enemies.min(by:{snapshot[$0].p.distance(b.p)<snapshot[$1].p.distance(b.p)}) else {bugs[i].opponentID=nil;bugs[i].fightTarget=nil;continue}
            bugs[i].opponentID=snapshot[enemy].id;bugs[i].fightTarget=snapshot[enemy].p
            // Acquire a rival first; movement closes the distance before a strike can land.
            if (b.attackCooldown ?? 0)<=0 && snapshot[enemy].p.distance(b.p)<=max(56,radius(b)+radius(snapshot[enemy])+18) {pairs.append((i,enemy))}
        }
        var attackerCounts:[Int:Int]=[:]
        for (_,enemy) in pairs {attackerCounts[enemy,default:0] += 1}
        for (i,enemy) in pairs {
            let b=snapshot[i],target=snapshot[enemy]
            let style:AttackStyle = b.bulkValue>=0.42 ? .ram : (b.species == .ant && b.morph>=3 ? .pincer : ((attackerCounts[enemy] ?? 0)>1 ? .swarm : .bite))
            let power=(b.species == .roach ? 1.5 : 0.55)*(b.role == .soldier ? 1.8 : 1)*(1+b.bulkValue*4)
            let cadence=style == .ram ? 1.8 : (style == .pincer ? 1.2 : 0.6)
            bugs[i].attackCooldown=cadence
            damage[enemy,default:0] += power*cadence
            let direction=(target.p-b.p).unit
            knockback[enemy,default:.zero] = (knockback[enemy] ?? .zero)+direction*(style == .ram ? 25 : (b.species == .roach ? 7 : 3))
            bugs[i].fightTime=0.6;bugs[enemy].hitTime=0.3
            bugs[i].angle=atan2(direction.y,direction.x)
            if fights.count<64 {
                fights.append(FightEffect(attacker:b.id,defender:target.id,from:b.p+direction*radius(b)*0.7,to:target.p-direction*radius(target)*0.7,swarm:(attackerCounts[enemy] ?? 0)>1,heavy:b.species == .roach,style:style,size:1+b.bulkValue*2.5))
            }
        }
        if !pairs.isEmpty && clock-battleEventTime>12 {
            let swarm=attackerCounts.values.contains{$0>1}
            record(swarm ? "围攻：多只成虫包围同一对手，扑击与反击" : "单挑：两只成虫为食物对峙交手")
            battleEventTime=clock
        }
        for (i,amount) in damage {
            bugs[i].health -= amount
            let push=knockback[i] ?? .zero
            bugs[i].p=safeBug(bugs[i].p+push.unit*(min(28,push.length)/(1+bugs[i].bulkValue*3)),bugs[i])
        }
        let victims=bugs.filter{$0.health<=0}
        guard !victims.isEmpty else {return}
        for var b in victims {
            if b.cargo>0 {_ = addFood(b.p,portions:b.cargo,announce:false)}
            b.cargo=0;b.flight=nil;b.speed=0;b.fightTime=0;b.opponentID=nil;b.fightTarget=nil;b.hitTime=nil
            corpses.append(Corpse(bug:b));spillJuice(b,crushed:false);combatDeaths += 1
            ensureDay();if b.species == .roach {reports[reports.count-1].roachLost += 1} else {reports[reports.count-1].antLost += 1}
        }
        let dead=Set(victims.map{$0.id});bugs.removeAll{dead.contains($0.id)}
        if corpses.count>160 {let excess=corpses.count-160;archivedCorpses += excess;corpses.removeFirst(excess)}
        let atNest=victims.contains{$0.p.distance(roachNest)<110 || $0.p.distance(antNest)<110}
        let carrying=victims.contains{$0.cargo>0}
        record((atNest ? "巢区冲突" : (carrying ? "搬运拦截战" : "食物争夺战"))+"：蟑螂损失 \(victims.filter{$0.species == .roach}.count)，蚂蚁损失 \(victims.filter{$0.species == .ant}.count)")
        say("挤在一起抢食，双方发生冲突。尸体留在桌面。")
    }
    func resize(width: Double,height: Double) {
        fights.removeAll();sweeps.removeAll()
        let sx = width/self.width, sy = height/self.height
        self.width = width; self.height = height
        for i in bugs.indices { bugs[i].flight=nil;bugs[i].layTime=0;bugs[i].p = safeBug(V(x:bugs[i].p.x*sx,y:bugs[i].p.y*sy),bugs[i]) }
        for i in foods.indices { foods[i].p = safe(V(x:foods[i].p.x*sx,y:foods[i].p.y*sy)) }
        for i in invaders.indices {invaders[i].p=safe(V(x:invaders[i].p.x*sx,y:invaders[i].p.y*sy))}
        for i in eggs.indices { eggs[i].layAge=3;eggs[i].layStart=nil;eggs[i].p = safe(V(x:eggs[i].p.x*sx,y:eggs[i].p.y*sy)) }
        for i in shelters.indices {shelters[i].p=safe(V(x:shelters[i].p.x*sx,y:shelters[i].p.y*sy))}
        for i in corpses.indices { corpses[i].bug.p = safe(V(x:corpses[i].bug.p.x*sx,y:corpses[i].bug.p.y*sy)) }
        let inkScale=min(sx,sy)
        for i in splats.indices {
            splats[i].p=safe(V(x:splats[i].p.x*sx,y:splats[i].p.y*sy))
            splats[i].radius=min(240,splats[i].radius*inkScale)
            for j in splats[i].drops.indices {splats[i].drops[j].offset=splats[i].drops[j].offset*inkScale;splats[i].drops[j].radius=min(80,splats[i].drops[j].radius*inkScale)}
        }
    }
    func update(_ delta: Double) {
        guard !paused else { return }
        let dt = min(max(delta,0),0.08)
        dateCheck += dt
        if dateCheck>1 {ensureDay();dateCheck=0}
        sprayCooldown=max(0,sprayCooldown-dt);for i in sprays.indices {sprays[i].age += dt};sprays.removeAll{$0.age>1.2};for cloud in sprays where cloud.age<0.75 {_ = poisonBugs(at:cloud.p)}
        clock += dt; notice.time -= dt; eventCooldown -= dt; slapTime = max(0,slapTime-dt)
        for i in splats.indices {splats[i].age=min(4,splats[i].age+dt)}
        for i in sweeps.indices {sweeps[i].age += dt};sweeps.removeAll{$0.age >= $0.duration}
        for i in fights.indices {fights[i].age += dt}
        fights.removeAll{$0.age >= $0.duration}
        for i in puffs.indices { puffs[i].life -= dt; puffs[i].p = puffs[i].p + puffs[i].velocity*dt }
        puffs.removeAll{$0.life<=0}
        for i in trails.indices { trails[i].life -= dt }; trails.removeAll{$0.life<=0}
        guard mode != .result else { return }
        diplomacy(dt)
        if mode == .battle {
            remaining = max(0,remaining-dt)
            if remaining <= 0 { mode = .result; grabbedID = nil; pointer = nil; say(resultTitle,force:true); return }
        }
        autoFoodTime += dt
        if autoFoodTime > (mode == .battle ? 12 : 7) && foods.count < 10 {
            autoFoodTime = 0
            let foodPoint = filming ? V(x:random.range(field.minX+45,field.maxX-45),y:random.range(field.minY+100,field.maxY-100)) : V(x:random.range(width*0.2,width*0.72),y:random.range(height*0.28,height*0.78))
            _ = addFood(foodPoint,kind:Snack.allCases[foodSerial % 4],announce:false)
        }
        lifecycle(dt * (mode == .battle ? 1 : lifeRate))
        updateInvaders(dt)
        combatTimer += dt
        if combatTimer>=0.6 { resolveCrowding(combatTimer); combatTimer=0 }
        let snapshot = bugs
        let sizes=Dictionary(uniqueKeysWithValues:snapshot.map{($0.id,radius($0))})
        let large=snapshot.filter{(sizes[$0.id] ?? 0)>55}
        var cells:[Int:[Bug]]=[:]
        func cellKey(_ x:Int,_ y:Int)->Int { (x+10000)*100000+y+10000 }
        for b in snapshot {cells[cellKey(Int(b.p.x/64),Int(b.p.y/64)),default:[]].append(b)}
        func neighbors(_ p:V)->[Bug] {
            let x=Int(p.x/64),y=Int(p.y/64)
            var result:[Bug]=[]
            for dx in -1...1 {for dy in -1...1 {result += cells[cellKey(x+dx,y+dy)] ?? []}}
            return result
        }
        trailTime += dt
        let depositTrail = trailTime > 0.3
        if depositTrail { trailTime = 0 }
        for i in bugs.indices {
            if bugs[i].id == grabbedID { continue }
            var b = bugs[i]
            if (b.layTime ?? 0)>0 {b.speed=0;b.phase += dt*1.5;bugs[i]=b;continue}
            b.flightWait=max(0,(b.flightWait ?? Double(8+b.id%13))-dt)
            if b.flight == nil && b.cargo==0 && (b.flightWait ?? 0)<=0 && b.fightTime<=0 && b.opponentID == nil && bugs.filter({$0.flight != nil}).count<2 {_ = beginFlight(&b)}
            if fly(&b,dt) {bugs[i]=b;continue}
            let selfRadius=sizes[b.id] ?? 0
            let local=neighbors(b.p)
            let localIDs=Set(local.map{$0.id})
            let extra=(selfRadius>55 ? snapshot : large).filter{!localIDs.contains($0.id) && $0.p.distance(b.p)<(sizes[$0.id] ?? 0)+selfRadius+55}
            let nearby=(local+extra).filter{$0.flight == nil}
            b.fightTime=max(0,b.fightTime-dt)
            b.hitTime=max(0,(b.hitTime ?? 0)-dt)
            b.webTime=max(0,(b.webTime ?? 0)-dt);b.bitePulse=max(0,(b.bitePulse ?? 0)-dt)
            let shown=b.shownBulk ?? b.bulkValue
            b.shownBulk=shown+(b.bulkValue-shown)*min(1,dt*8)
            b.cooldown = max(0,b.cooldown-dt); b.scared = max(0,b.scared-dt)
            if b.flipped > 0 {
                b.flipped = max(0,b.flipped-dt); b.speed = 0; b.phase += dt*14
                let helpers = nearby.filter{$0.species == .ant && $0.p.distance(b.p)<42 && $0.cargo==0}
                if helpers.count >= 2 { b.p = safe(b.p + (antNest-b.p).unit*(dt*13)); b.angle += dt*0.18 }
                if b.flipped == 0 { b.scared = 3.5; b.cooldown = 4; burst(b.p,kind:1,count:6); say("装死结束。到手的蟑螂跑了！",force:true) }
                bugs[i] = b; continue
            }
            let isRoach = b.species == .roach
            let nest = isRoach ? roachNest : antNest
            var goal = b.wander
            var speed: Double = isRoach ? 79 : 53
            if mode == .companion { speed *= 0.72 }
            speed *= (0.65 + b.growth*0.35) * (b.adult && b.role == .scout ? 1.3 : (b.role == .soldier ? 0.85 : 1))
            if b.fightTime>0 {speed *= 0.3}
            var hasGoal = false
            if b.cargo > 0 {
                goal = nest; hasGoal = true; speed *= isRoach ? 0.87 : 0.82
                if b.p.distance(nest) < max(26,(b.species == .roach ? 89 : 18)*scale(for:b)+18) {
                    if isRoach { roachScore += b.cargo; roachFood += b.cargo } else { antScore += b.cargo; antFood += b.cargo }
                    reports[reports.count-1].foodDelivered += b.cargo
                    burst(b.p,kind:isRoach ? 2 : 3,count:4)
                    b.cargo = 0; b.cooldown = 0.5
                }
            } else if !isRoach, let flipped = snapshot.filter({$0.species == .roach && $0.flipped>1}).min(by:{$0.p.distance(b.p)<$1.p.distance(b.p)}), flipped.p.distance(b.p) < 230 {
                let a = Double(b.id)*2.39996
                goal = flipped.p + V(x:cos(a)*25,y:sin(a)*25); hasGoal = true
                if b.p.distance(goal)<8 { speed = 10 }
            } else if let nearest = foods.filter({$0.portions>0}).min(by:{
                let da = $0.p.distance(b.p), db = $1.p.distance(b.p)
                return da < db
            }) {
                b.targetFood = nearest.id
                // Ants share a route; a narrow ID-dependent lane produces a readable column.
                let feedingDistance=radius(b)+foodRadius(nearest)*0.78
                goal = safeBug(nearest.p+(b.p-nearest.p).unit*feedingDistance,b)
                if !isRoach && b.bulkValue<0.42 && b.p.distance(goal)>max(75,feedingDistance+30) {
                    let route = nearest.p-antNest
                    let length = max(1,route.length)
                    let projection = max(0,min(1,((b.p-antNest).x*route.x+(b.p-antNest).y*route.y)/(length*length)))
                    let ahead = min(1,projection + 55/length)
                    goal = antNest + route*ahead + V(x:-route.unit.y,y:route.unit.x)*Double((b.id%3)-1)*13
                }
                hasGoal = true
                if b.p.distance(nearest.p) < max(isRoach ? 23 : 19,feedingDistance+12) && b.cooldown == 0,
                   let f = foods.firstIndex(where:{$0.id==nearest.id}) {
                    bite(&b,food:f)
                }
            }
            if !hasGoal {
                b.wanderTime -= dt
                if b.wanderTime <= 0 || b.p.distance(b.wander)<20 {
                    b.wander = safe(V(x:random.range(field.minX+15,field.maxX-15),y:random.range(field.minY+25,field.maxY-15)))
                    b.wanderTime = random.range(3,7)
                }
                goal = b.wander; speed *= 0.65
            }
            if relations == .hostile && isRoach && b.adult && b.cooldown == 0 && b.cargo == 0,
               let victim = bugs.indices.first(where:{bugs[$0].species == .ant && bugs[$0].cargo>0 && bugs[$0].p.distance(b.p)<23}) {
                b.cargo = bugs[victim].cargo; bugs[victim].cargo = 0; bugs[victim].scared = 1.6
                b.cooldown = 3; say("半路截胡！蟑螂抢了搬运工的口粮。")
            }
            if relations == .hostile && isRoach && b.cargo > 0 && b.cooldown == 0 {
                let crowd = nearby.filter{$0.species == .ant && $0.p.distance(b.p)<58}
                if crowd.count >= 4 {
                    _ = addFood(b.p,portions:b.cargo,announce:false); b.cargo = 0; b.scared = 2.5; b.cooldown = 4
                    say("蚂蚁把它围住了。食物留下！",force:true)
                }
            }
            if relations == .hostile && !isRoach && b.cargo==0, let thief = snapshot.first(where:{$0.species == .roach && $0.cargo>0 && $0.flipped==0 && $0.p.distance(b.p)<100}) {
                goal = thief.p; speed *= 1.18
            }
            if relations == .hostile && b.adult && b.role == .soldier && b.cargo==0 && (isRoach ? roachFood : antFood)<8 && bugs.count>65 {
                goal=isRoach ? antNest : roachNest;speed *= 1.15
            }
            if relations == .hostile, let opponent=b.opponentID, let enemy=snapshot.first(where:{$0.id==opponent && $0.flight == nil}) {
                b.fightTarget=enemy.p
                let toEnemy=enemy.p-b.p
                let attackers=snapshot.filter{$0.opponentID==enemy.id}.count
                if attackers>1 {
                    let angle=Double(b.id)*2.39996
                    let reach=max(48,radius(b)+radius(enemy)+8)
                    goal=safeBug(enemy.p+V(x:cos(angle)*reach,y:sin(angle)*reach),b)
                } else {goal=safeBug(enemy.p-toEnemy.unit*max(48,radius(b)+radius(enemy)+8),b)}
                if b.bulkValue>=0.42 && (b.attackCooldown ?? 0)>0.6 {goal=safeBug(goal-toEnemy.unit*32,b)}
                speed=max(speed,b.bulkValue>=0.42 && (b.attackCooldown ?? 0)<=0.6 ? 120 : 45)
                if b.p.distance(goal)<8 {speed=5}
                b.angle=atan2(toEnemy.y,toEnemy.x)
            }
            if b.adult,let intruder=invaders.filter({!$0.dead && $0.age<38}).min(by:{$0.p.distance(b.p)<$1.p.distance(b.p)}),b.p.distance(intruder.p)<radius(b)+260 {
                let reach=radius(b)+45,a=Double(b.id)*2.39996
                goal=safeBug(intruder.p+V(x:cos(a)*reach,y:sin(a)*reach),b)
                b.angle=atan2(intruder.p.y-b.p.y,intruder.p.x-b.p.x)
                if b.fightTime>0 {b.fightTarget=intruder.p}
            }
            if let nursery=shelterGoal(b) {goal=nursery;hasGoal=true;b.angle=atan2(nursery.y-b.p.y,nursery.x-b.p.x)}
            if b.scared > 0 {
                let source = slap ?? pointer ?? V(x:width/2,y:height/2)
                goal = safe(b.p+(b.p-source).unit*140); speed *= 1.75
            }
            var direction = (goal-b.p).unit
            var separation = V.zero
            for other in nearby where other.id != b.id && other.species == b.species {
                let offset = b.p-other.p, d = offset.length
                let distance:Double=max(isRoach ? 52 : 17,selfRadius+(sizes[other.id] ?? 0))
                if d>0.1 && d<distance { separation = separation+offset.unit*((distance-d)/distance) }
            }
            direction = (direction+separation*(isRoach ? 0.95 : 1.35)).unit
            if isRoach { let wobble = sin(clock*4+Double(b.id)*3)*0.19; direction = (direction+V(x:-direction.y,y:direction.x)*wobble).unit }
            if (goal-b.p).length < 6 { speed *= 0.25 }
            speed *= 1-b.bulkValue*0.4
            if (b.webTime ?? 0)>0 {speed *= 0.25}
            b.p = safeBug(b.p+direction*(speed*dt),b); b.speed = speed
            if direction.length > 0.1 && b.opponentID == nil {
                let desired = atan2(direction.y,direction.x)
                var difference = desired-b.angle
                while difference > Double.pi { difference -= 2*Double.pi }
                while difference < -Double.pi { difference += 2*Double.pi }
                b.angle += difference*min(1,dt*9)
            }
            b.phase += dt*speed*0.18
            if !isRoach && depositTrail && b.cargo > 0 { trails.append(Trail(p:b.p,life:4)) }
            bugs[i] = b
        }
        foods.removeAll{$0.portions<=0}
        if trails.count > 300 { trails.removeFirst(trails.count-300) }
    }
}

func runWorldTests() {
    var checks = 0
    func check(_ ok: @autoclosure () -> Bool, _ label: String) {
        if !ok() { fputs("FAIL: \(label)\n",stderr); exit(1) }
        checks += 1; print("PASS: \(label)");fflush(stdout)
    }
    let w = World(width:1440,height:900,seed:42)
    check(w.bugs.count==40,"companion population bounded")
    w.startRound(); check(w.bugs.count==52 && w.mode == .battle,"round starts with both populations")
    let start = w.remaining; w.paused = true; w.update(0.05)
    check(w.remaining == start,"pause freezes round")
    w.paused = false
    for _ in 0..<1200 { w.update(0.05) }
    check(w.roachScore>0 && w.antScore>0,"both species find food and score autonomously")
    check(w.foods.allSatisfy{$0.portions>0},"no exhausted or negative food stacks")
    w.tool = .slipper
    let victim = w.bugs.first{$0.species == .roach}!
    w.press(victim.p)
    check(!w.bugs.contains{$0.id == victim.id} && w.corpses.contains{$0.bug.id == victim.id},"slipper kills and leaves corpse")
    for _ in 0..<180 { w.update(0.05) }
    check(!w.bugs.contains{$0.id == victim.id} && w.corpses.contains{$0.bug.id == victim.id},"dead creature never revives and corpse persists")
    let ri = w.bugs.startIndex
    w.tool = .grab; let p = w.bugs[ri].p; w.press(p); let id = w.grabbedID
    w.drag(V(x:600,y:450))
    check(id != nil && w.bugs.first{$0.id==id}!.p == V(x:600,y:450),"grab relocates selected creature")
    w.release(); check(w.grabbedID==nil,"release clears drag")
    for _ in 0..<40 { _ = w.addFood(V(x:500,y:500),announce:false) }
    check(w.foods.count<=18,"food count capped under repeated clicks")
    w.remaining = 0.01; w.update(0.05)
    check(w.mode == .result && w.grabbedID==nil,"timer finishes and releases input state")
    let score = w.roachScore+w.antScore; w.update(0.05)
    check(w.roachScore+w.antScore==score,"result freezes scoring")
    w.companion(); check(w.mode == .companion && !w.paused,"escape companion resets safely")
    w.resize(width:800,height:600)
    for _ in 0..<100 { w.update(0.05) }
    check(w.bugs.allSatisfy{$0.p.x>=25 && $0.p.x<=775 && $0.p.y>=35 && $0.p.y<=565},"creatures remain in bounds after display resize")
    for seed in 1...12 {
        let sim = World(width:1280,height:800,seed:UInt64(seed)); sim.startRound()
        for _ in 0..<3001 { sim.update(0.05) }
        check(sim.mode == .result && sim.roachScore>0 && sim.antScore>0,"complete autonomous round seed \(seed)")
    }
    let life = World(width:1000,height:700,seed:81)
    life.roachFood = 100; life.antFood = 100
    for _ in 0..<2200 { life.update(0.05) }
    check(life.hatchedCount > 0 && life.maturedCount > 0,"autonomous laying hatching and maturation")
    check(life.bugs.contains{$0.generation > 1},"offspring carry next generation")
    check(life.reserved(.roach)<=60 && life.reserved(.ant)<=240,"eggs reserve bounded population slots")
    check(Set(life.bugs.map{$0.id}+life.eggs.map{$0.id}).count == life.bugs.count+life.eggs.count,"unique identities across eggs and bugs")
    let starving = World(width:1000,height:700,seed:3)
    starving.foods=[]; starving.roachFood=0; starving.antFood=0
    starving.bugs[0].growth=0.2
    for _ in 0..<1000 { starving.lifecycle(0.05) }
    check(starving.eggs.isEmpty && starving.bugs[0].growth==0.2,"no food stops both reproduction and growth")
    let remnant = World(width:1000,height:700,seed:8)
    remnant.bugs=[]; remnant.eggs=[Egg(id:900,species:.roach,p:V(x:400,y:400),hatchTime:1,generation:2)]
    remnant.bugSerial=901
    for _ in 0..<30 { remnant.lifecycle(0.05) }
    check(remnant.bugs.count==1 && remnant.bugs[0].growth<1,"surviving prepaid egg hatches after adults die")
    remnant.ecologyInteractive=true; remnant.tool = .slipper; remnant.press(remnant.bugs[0].p)
    check(remnant.bugs.isEmpty && remnant.corpses.count==1,"juveniles can be killed in interactive ecology")
    for _ in 0..<1200 { remnant.update(0.05) }
    check(remnant.bugs.isEmpty && remnant.eggs.isEmpty,"extinction never respawns insects")
    remnant.tool = .clean; remnant.press(remnant.corpses[0].bug.p)
    check(remnant.corpses.isEmpty,"cleanup removes corpses")
    let oldIDs = life.bugs.map{$0.id}; let oldEggs = life.eggs.count
    life.companion()
    check(life.bugs.map{$0.id} == oldIDs && life.eggs.count == oldEggs,"return to work preserves the colony")
    life.paused=true; let age=life.eggs.first?.age; life.update(0.05)
    check(life.eggs.first?.age == age,"pause freezes egg development")
    let clean = World(width:1000,height:700,seed:9)
    clean.ecologyInteractive=true; clean.tool = .clean
    clean.eggs=[Egg(id:999,species:.ant,p:V(x:500,y:300),hatchTime:22,generation:2)]
    clean.press(V(x:500,y:300)); check(clean.eggs.isEmpty,"cleanup can remove eggs")
    let film = World(width:1440,height:900,seed:11)
    film.toggleFilming()
    for _ in 0..<3000 {film.update(0.05)}
    check(film.filming && film.bugs.allSatisfy{film.field.contains(CGPoint(x:$0.p.x,y:$0.p.y))},"vertical field keeps autonomous bugs in frame")
    check(abs(film.field.width/film.field.height-9.0/16)<0.001,"filming field is 9:16")
    check(film.hatchedCount>0 && film.reserved(.roach)<=60,"clutches hatch without exceeding reserved population")
    let clutch=World(width:1000,height:700,seed:16)
    clutch.bugs=[]; clutch.eggs=[Egg(id:990,species:.roach,p:V(x:400,y:400),hatchTime:1,generation:3,brood:3)]
    clutch.bugSerial=991; clutch.watchedID=990
    for _ in 0..<65 {clutch.lifecycle(0.05)}
    check(clutch.bugs.count==3 && clutch.eggs.isEmpty,"one roach egg case hatches three real offspring in sequence")
    check(clutch.watchedID==991 && clutch.observation?.1.contains("第3代")==true,"observation follows egg into first offspring")
    clutch.ecologyInteractive=true; clutch.tool = .observe; clutch.paused=true
    clutch.press(clutch.bugs[0].p)
    check(clutch.watchedID != nil,"observation works while paused")
    let fast=World(width:1000,height:700,seed:22)
    fast.bugs=[]; fast.eggs=[Egg(id:900,species:.ant,p:V(x:400,y:400),hatchTime:22,generation:2)]
    fast.cycleRate(); fast.cycleRate()
    for _ in 0..<120 {fast.update(0.05)}
    check(fast.hatchedCount==1 && fast.lifeRate==4,"fourfold life speed advances real hatching")
    fast.startRound(); let timer=fast.remaining; fast.update(0.05)
    check(abs(fast.remaining-(timer-0.05))<0.001,"battle timer unaffected by life speed control")
    let placed=World(width:1000,height:700,seed:41)
    placed.paused=true; placed.ecologyInteractive=true; placed.tool = .roachEgg
    placed.press(V(x:350,y:300)); placed.tool = .antEgg; placed.press(V(x:650,y:300))
    check(placed.eggs.count==2 && placed.eggs[0].brood==3 && placed.eggs[1].brood==1,"both egg tools place visible viable eggs while paused")
    check(placed.eggs[0].p==V(x:350,y:300) && placed.eggs[1].p==V(x:650,y:300),"egg placement uses selected desktop coordinates")
    for _ in 0..<20 {_ = placed.placeEgg(.roach,at:V(x:350,y:300))}
    check(placed.reserved(.roach)<=60,"manual eggs obey population budget")
    let before=placed.hatchedCount; placed.paused=false
    for _ in 0..<650 {placed.update(0.05)}
    check(placed.hatchedCount>before,"manually placed eggs really hatch after resuming")
    let panelTraffic=World(width:1440,height:780,seed:45)
    panelTraffic.avoid=CGRect(x:1094,y:26,width:324,height:690)
    panelTraffic.bugs=panelTraffic.bugs.filter{$0.species == .ant}
    for i in panelTraffic.bugs.indices {
        panelTraffic.bugs[i].p=V(x:1063,y:400+Double(i)*15)
        panelTraffic.bugs[i].cargo=1; panelTraffic.bugs[i].breeder=false
    }
    panelTraffic.foods=[]; panelTraffic.autoFoodTime = -10000
    for _ in 0..<1000 {panelTraffic.update(0.05)}
    check(panelTraffic.antScore==32 && panelTraffic.bugs.allSatisfy{$0.cargo==0},"loaded ants reach nest even when control card overlaps return route")
    let dense=World(width:1000,height:700,seed:123)
    dense.bugs=[];dense.eggs=[];dense.foods=[]
    for i in 0..<24 {var b=Bug(id:i,species:i<6 ? .roach : .ant,p:V(x:500+Double(i%4),y:350+Double(i/4)));b.health=b.toughness;dense.bugs.append(b)}
    for _ in 0..<50 {dense.resolveCrowding(0.6)}
    check(dense.combatDeaths>0 && dense.bugs.count<24 && !dense.corpses.isEmpty,"crowded opposing adults fight and leave real corpses")
    let sparse=World(width:1000,height:700,seed:5)
    sparse.bugs=[Bug(id:100,species:.roach,p:V(x:400,y:300)),Bug(id:101,species:.ant,p:V(x:405,y:300))]
    sparse.foods=[]
    for _ in 0..<50 {sparse.resolveCrowding(0.6)}
    check(sparse.combatDeaths==0 && sparse.bugs.count==2,"sparse encounters do not become automatic deaths")
    let rich=World(width:1440,height:900,seed:8)
    rich.roachFood=10000;rich.antFood=10000
    for _ in 0..<6000 {rich.lifecycle(0.05)}
    check(rich.population(.roach)>12 && rich.population(.ant)>60,"well fed ecology grows beyond old population limits")
    check(rich.reserved(.roach)<=60 && rich.reserved(.ant)<=240,"large ecology reserves offspring within safety caps")
    check(rich.bugs.contains{$0.adult && $0.role == .soldier} && rich.bugs.contains{$0.adult && $0.role == .scout},"adult roles emerge alongside growing offspring")
    rich.foods=[]
    for snack in Snack.allCases {_ = rich.addFood(V(x:300,y:300),kind:snack,announce:false)}
    check(Set(rich.foods.map{$0.snack.rawValue}).count==6 && rich.foods.map{$0.original}==[24,64,42,32,900,1200],"six snacks preserve nutrition including giant meals")
    let peace=World(width:1000,height:700,seed:121)
    peace.bugs=dense.corpses.map{$0.bug};for i in peace.bugs.indices {peace.bugs[i].health=10}
    peace.setRelations(.truce,reason:"测试停火")
    let peaceCount=peace.bugs.count
    for _ in 0..<20 {peace.resolveCrowding(0.6)}
    check(peace.bugs.count==peaceCount && peace.combatDeaths==0,"truce stops lethal crowd combat")
    peace.roachFood=100;peace.antFood=20;peace.setRelations(.trade,reason:"测试建交")
    let total=peace.roachFood+peace.antFood;peace.diplomacy(16)
    check(peace.roachFood==96 && peace.antFood==24 && total==peace.roachFood+peace.antFood,"trade transfers food without creating nutrition")
    let memory=try! rich.saveData(),restored=World(width:1440,height:900,seed:1)
    try! restored.restore(memory)
    check(restored.bugs.count==rich.bugs.count && restored.eggs.count==rich.eggs.count && restored.reports.last?.roachBorn==rich.reports.last?.roachBorn,"save restores live ecology and actual daily history")
    let previousDays=peace.reports.count
    peace.ensureDay(Date().addingTimeInterval(86400))
    check(peace.reports.count==previousDays+1 && peace.reports.last?.trades==0,"new calendar day has separate counters")
    let treaty=World(width:1000,height:700,seed:66)
    treaty.combatDeaths=6;treaty.relationAge=46;treaty.diplomacy(0.05)
    check(treaty.relations == .truce,"sustained losses trigger an automatic ceasefire")
    treaty.roachFood=20;treaty.antFood=20;treaty.diplomacy(41)
    check(treaty.relations == .trade,"a supplied ceasefire develops into diplomatic trade")
    treaty.roachFood=0;treaty.diplomacy(101)
    check(treaty.relations == .hostile,"prolonged food shortage can break a treaty")
    check(dense.reports.last!.roachLost+dense.reports.last!.antLost==dense.combatDeaths,"daily casualty totals match actual combat deaths")
    let duel=World(width:1000,height:700,seed:17)
    duel.bugs=[Bug(id:1,species:.roach,p:V(x:430,y:350)),Bug(id:2,species:.ant,p:V(x:478,y:350))];duel.eggs=[];duel.foods=[]
    for i in duel.bugs.indices {duel.bugs[i].health=duel.bugs[i].toughness}
    _ = duel.addFood(V(x:454,y:350),kind:.cake,announce:false)
    duel.resolveCrowding(0.6)
    check(duel.bugs.allSatisfy{$0.opponentID != nil} && duel.fights.count==2,"one versus one acquires opponents and produces attack motion")
    check(duel.bugs[0].health<10 && duel.bugs[1].health<4,"duel exchanges actual damage in both directions")
    let surround=World(width:1000,height:700,seed:18)
    surround.bugs=[Bug(id:1,species:.roach,p:V(x:500,y:350))];surround.eggs=[];surround.foods=[]
    for i in 2...7 {let a=Double(i)*1.05;surround.bugs.append(Bug(id:i,species:.ant,p:V(x:500+cos(a)*45,y:350+sin(a)*45)))}
    _ = surround.addFood(V(x:500,y:350),kind:.cake,announce:false)
    surround.resolveCrowding(0.6)
    check(surround.fights.contains{$0.swarm} && surround.bugs.filter{$0.opponentID==1}.count>=3,"multiple attackers converge on one defender")
    surround.setRelations(.truce,reason:"特效停止测试")
    check(surround.fights.isEmpty && surround.bugs.allSatisfy{$0.opponentID==nil && $0.fightTime==0},"ceasefire immediately clears attack effects and target locks")
    duel.paused=true;let firstAge=duel.fights.first!.age;duel.update(0.05)
    check(duel.fights.first!.age==firstAge,"pause freezes combat effects alongside the world")
    let feast=World(width:1440,height:900,seed:44)
    feast.bugs=[Bug(id:100,species:.ant,p:V(x:700,y:450)),Bug(id:101,species:.roach,p:V(x:450,y:450))]
    feast.bugSerial=102;feast.eggs=[];feast.foods=[];feast.autoFoodTime = -10000;feast.invasionTimer=10000
    feast.setRelations(.truce,reason:"进食测试")
    _ = feast.addFood(V(x:720,y:450),kind:.pizza,announce:false)
    let originalFood=feast.foods[0].portions,smallSize=feast.scale(for:feast.bugs[0],animated:false)
    feast.biteBug(at:0,food:0)
    check(feast.foods[0].portions<originalFood && feast.bugs[0].meals==1 && feast.bugs[0].bulkValue>0,"actual bite consumes food and advances individual growth")
    check(feast.scale(for:feast.bugs[0],animated:false)>smallSize*1.5,"one giant meal bite gives a visible ant size increase")
    let once=feast.bugs[0].bulkValue;feast.biteBug(at:0,food:0)
    check(feast.bugs[0].bulkValue==once,"cooldown prevents click spamming free growth")
    for _ in 0..<6 {for i in feast.bugs.indices {feast.bugs[i].cooldown=0;feast.biteBug(at:i,food:0)}}
    check(feast.bugs.allSatisfy{$0.bulkValue==1 && $0.morph==4},"both camps reach their distinct titan morphology")
    let rk=feast.scale(for:feast.bugs[1],animated:false),ak=feast.scale(for:feast.bugs[0],animated:false)
    check(abs(130*78*rk*rk/(feast.field.width*feast.field.height)-0.25)<0.01,"giant roach visual envelope reaches a quarter of the field")
    check(abs((26*ak)/(65*rk)-0.5)<0.001,"largest ant body length is half the largest roach")
    feast.bugs[0].shownBulk=1;let titan=feast.bugs[0]
    let edge=titan.p+V(x:10*feast.scale(for:titan),y:0)
    check(feast.bodyHit(titan,edge),"giant body is hit-testable away from its old center")
    feast.ecologyInteractive=true;feast.tool = .slipper;feast.press(edge)
    check(!feast.bugs.contains{$0.id==100} && feast.corpses.contains{$0.bug.id==100},"giant hitbox supports actual swat death")
    feast.tool = .clean;let live=feast.bugs.count;feast.press(edge)
    check(feast.corpses.isEmpty && feast.bugs.count==live && feast.sweeps.last?.bodies.count==1,"broom removes giant corpses with sweep animation while preserving live bugs")
    feast.eggs=[Egg(id:103,species:.ant,p:V(x:500,y:500),hatchTime:22,generation:1)];feast.bugSerial=104
    feast.press(V(x:400,y:500));feast.drag(V(x:500,y:500));feast.release()
    check(feast.eggs.isEmpty && feast.sweepAnchor==nil,"dragging broom sweeps eggs along its path and releases cleanly")
    feast.paused=true;let sweepAge=feast.sweeps.last!.age;feast.update(0.05)
    check(feast.sweeps.last!.age==sweepAge,"pause freezes broom animation")
    let modest=World(width:1440,height:900,seed:2);modest.foods=[]
    _ = modest.addFood(V(x:400,y:400),portions:1000,kind:.cookie,announce:false)
    for _ in 0..<15 {modest.bugs[0].cooldown=0;modest.biteBug(at:0,food:0)}
    check(modest.bugs[0].bulkValue==0.30,"ordinary snacks preserve normal adults and require a giant meal for larger forms")
    check(modest.snackScale(.pizza)>5 && modest.snackScale(.cookie)==1,"giant food has a real viewport-scaled footprint")
    let intrude=World(width:1440,height:900,seed:81);intrude.bugs=[];intrude.eggs=[];intrude.foods=[]
    _ = intrude.summonInvader(.spider);let center=intrude.invaders[0].p
    intrude.bugs=[Bug(id:90,species:.ant,p:center+V(x:45,y:0))];intrude.bugSerial=91
    intrude.setRelations(.truce,reason:"外敌测试");intrude.invaders[0].cooldown=0;intrude.updateInvaders(0.05)
    check((intrude.bugs[0].webTime ?? 0)>0 && intrude.bugs[0].health<10,"spider entangles and damages a real victim")
    check(intrude.invaders[0].health<95 && intrude.relations == .truce,"adults defend against invaders without breaking their treaty")
    check(!intrude.summonInvader(.beetle) && intrude.invaders.count==1,"only one living foreign invader may enter at a time")
    intrude.invaders[0].health=0;_ = intrude.summonInvader(.beetle)
    let inv=intrude.invaders.count-1;intrude.invaders[inv].cooldown=0
    _ = intrude.addFood(intrude.invaders[inv].p,kind:.pizza,announce:false)
    let prior=intrude.foods[0].portions;intrude.updateInvaders(0.05)
    check(intrude.foods[0].portions==prior-24 && intrude.invaders[inv].stolen==24,"beetle raids subtract actual food nutrition")
    intrude.invaders[inv].age=43;intrude.updateInvaders(0.05)
    check(!intrude.invaders.contains{$0.kind == .beetle},"surviving raiders depart after their encounter")
    let saved=try! feast.saveData(),loaded=World(width:1440,height:900,seed:1);try! loaded.restore(saved)
    check(loaded.bugs[0].bulkValue==1 && loaded.bugs[0].meals==feast.bugs[0].meals,"save round-trip preserves titan growth and feeding count")
    var legacy=try! JSONSerialization.jsonObject(with:saved) as! [String:Any]
    legacy.removeValue(forKey:"invaders")
    var legacyBugs=legacy["bugs"] as! [[String:Any]]
    for i in legacyBugs.indices {for key in ["bulk","shownBulk","bitePulse","meals","webTime","attackCooldown"] {legacyBugs[i].removeValue(forKey:key)}}
    legacy["bugs"]=legacyBugs;try! loaded.restore(JSONSerialization.data(withJSONObject:legacy))
    check(loaded.bugs[0].bulkValue==0 && loaded.invaders.isEmpty,"legacy saves without growth and invader fields still load")
    let drops=World(width:1000,height:700,seed:3);drops.foods=[];drops.selectedSnack = .pizza
    _ = drops.addFood(V(x:300,y:300),portions:8,announce:false)
    check(drops.foods[0].snack == .cookie && drops.snackScale(drops.foods[0].snack)==1,"dropped cargo cannot accidentally become a giant pizza")
    drops.ecologyInteractive=true;drops.tool = .clean
    drops.eggs=[Egg(id:2000,species:.ant,p:V(x:500,y:350),hatchTime:22,generation:1)]
    drops.press(V(x:100,y:350));drops.drag(V(x:900,y:350))
    check(drops.eggs.isEmpty,"fast broom drag cleans the whole swept segment")
    let mixed=World(width:1440,height:900,seed:9);mixed.bugs=[];mixed.eggs=[];mixed.foods=[]
    for i in 0..<100 {mixed.bugs.append(Bug(id:i,species:i<40 ? .roach : .ant,p:V(x:300,y:300)))}
    mixed.bugSerial=100
    _ = mixed.addFood(V(x:300,y:300),portions:1000000,kind:.pizza,announce:false)
    for i in mixed.bugs.indices {for _ in 0..<6 {mixed.bugs[i].cooldown=0;mixed.biteBug(at:i,food:0)}}
    check(mixed.bugs.filter{$0.bulkValue>=0.78}.count==2,"unlimited giant food creates only one final giant per camp")
    check(mixed.bugs.filter{$0.bulkValue<=0.30}.count>=80,"at least eighty percent remain normal-sized in a well-fed population")
    check(mixed.bugs.filter{$0.morph==3}.count==18,"medium-large adults coexist with both normal and giant forms")
    let leader=mixed.bugs.first{$0.species == .ant && $0.bulkValue>=0.78}!
    mixed.bugs.removeAll{$0.id==leader.id}
    let heir=mixed.bugs.firstIndex{$0.species == .ant && $0.bulkValue>0.30}!
    mixed.bugs[heir].cooldown=0;mixed.biteBug(at:heir,food:0)
    check(mixed.bugs[heir].bulkValue>=0.78,"a new giant can grow after the previous giant dies")
    for i in mixed.bugs.indices {mixed.bugs[i].bulk=1;mixed.bugs[i].shownBulk=1}
    let identities=mixed.bugs.map{$0.id},allMeals=mixed.bugs.map{$0.meals}
    try! loaded.restore(mixed.saveData())
    check(loaded.bugs.map{$0.id}==identities && loaded.bugs.map{$0.meals}==allMeals,"overgrown legacy save balances without losing individuals or meal history")
    check(loaded.bugs.filter{$0.bulkValue>=0.78}.count==2 && loaded.bugs.filter{$0.bulkValue<=0.30}.count>=79,"legacy overgrowth becomes a mixed population on load")
    let sizes=loaded.bugs.map{$0.bulkValue};try! loaded.restore(loaded.saveData())
    check(loaded.bugs.map{$0.bulkValue}==sizes,"population rebalance is stable across repeated restarts")
    var forms=Set<Int>();var formBug=Bug(id:3,species:.ant,p:.zero)
    for stage in [(0.1,0.0),(0.6,0.0),(1.0,0.1),(1.0,0.5),(1.0,1.0)] {formBug.growth=stage.0;formBug.bulk=stage.1;forms.insert(formBug.morph)}
    check(forms==Set(0...4),"five distinct growth forms from hatchling to giant")
    let goo=World(width:1440,height:900,seed:32);goo.bugs=[Bug(id:500,species:.roach,p:V(x:500,y:400))];goo.bugSerial=501;goo.eggs=[];goo.foods=[]
    goo.swat(V(x:500,y:400))
    check(goo.bugs.isEmpty && goo.corpses.count==1 && goo.splats.count==1,"swatting a real roach creates one corpse and one juice spill")
    check(goo.splats[0].crushed && goo.splats[0].drops.count>=32,"slipper kill emits many liquid droplets")
    let spill=goo.splats[0],drop=spill.drops[0]
    check(spill.offset(of:drop,at:0) == .zero && spill.offset(of:drop,at:2)==drop.offset,"droplets fly from impact and land at persistent stain positions")
    goo.slapTime=0;goo.swat(V(x:500,y:400))
    check(goo.splats.count==1,"already dead roaches cannot be farmed for duplicate splashes")
    let beforeInk=goo.random.value;var big=Bug(id:502,species:.roach,p:V(x:900,y:400));big.bulk=1;big.shownBulk=1
    goo.spillJuice(big,crushed:true)
    check(goo.random.value==beforeInk,"splash visuals do not perturb ecological randomness")
    check(goo.splats[1].radius>spill.radius*2 && goo.splats[1].drops.count>spill.drops.count,"giant roaches release a larger and denser splash")
    goo.paused=true;goo.update(0.05)
    check(goo.splats[0].age==0,"pause freezes flying liquid")
    goo.paused=false;for _ in 0..<40 {goo.update(0.05)}
    check(goo.splats.count==2 && goo.splats[0].age>1,"juice remains on the desktop after the flight animation")
    let dirtySave=try! goo.saveData();let afterGoo=World(width:1440,height:900,seed:1);try! afterGoo.restore(dirtySave)
    check(afterGoo.splats.count==2 && afterGoo.splats[0].drops.count==spill.drops.count,"save round-trip preserves puddles and landing droplets")
    goo.splats[0].age=0.05;try! afterGoo.restore(goo.saveData())
    check(afterGoo.splats[0].age>=1,"loading a save never replays the death explosion")
    var preJuice=try! JSONSerialization.jsonObject(with:dirtySave) as! [String:Any];preJuice.removeValue(forKey:"splats")
    try! afterGoo.restore(JSONSerialization.data(withJSONObject:preJuice))
    check(afterGoo.splats.isEmpty && afterGoo.corpses.count==1,"old Mac saves without juice fields still restore their corpses")
    try! afterGoo.restore(dirtySave);afterGoo.sweep(spill.p)
    check(afterGoo.corpses.isEmpty && !afterGoo.splats.contains{$0.bugID==500} && afterGoo.sweeps.last!.stains.contains{$0.bugID==500},"broom sweeps corpse and its juice into the same cleaning animation")
    let far=goo.splats[1],spot=far.drops.max{$0.offset.length<$1.offset.length}!.offset
    let floorPoint=far.p+V(x:spot.x*cos(far.angle)-spot.y*sin(far.angle),y:spot.x*sin(far.angle)+spot.y*cos(far.angle))
    check(far.hit(floorPoint,padding:1),"remote landing droplets have cleanable hit regions")
    try! afterGoo.restore(dirtySave);afterGoo.sweep(floorPoint)
    check(!afterGoo.splats.contains{$0.bugID==502},"broom also removes the outer splattered drops")
    try! afterGoo.restore(dirtySave);let oldInkRadius=afterGoo.splats[0].radius;afterGoo.resize(width:2880,height:1800)
    check(abs(afterGoo.splats[0].radius-oldInkRadius*2)<0.001 && afterGoo.splats[0].p==spill.p*2,"display resize keeps stains aligned and proportionate")
    let emptyHit=World(width:1000,height:700,seed:8);emptyHit.bugs=[];emptyHit.swat(V(x:500,y:350))
    check(emptyHit.splats.isEmpty,"a missed slipper slap creates no fake insect juice")
    emptyHit.slapTime=0;emptyHit.bugs=[Bug(id:600,species:.ant,p:V(x:500,y:350))];emptyHit.swat(V(x:500,y:350))
    check(emptyHit.splats.isEmpty && emptyHit.corpses.count==1,"ant deaths preserve their existing presentation")
    for n in 0..<130 {emptyHit.spillJuice(Bug(id:1000+n,species:.roach,p:V(x:500,y:350)),crushed:true)}
    check(emptyHit.splats.count==96 && emptyHit.splats.allSatisfy{$0.drops.count<=64},"heavy repeated deaths keep liquid rendering memory bounded")
    emptyHit.startRound();check(emptyHit.splats.isEmpty,"starting a fresh round clears the prior round's liquid")
    var badJuice=try! JSONSerialization.jsonObject(with:dirtySave) as! [String:Any]
    var badSplats=badJuice["splats"] as! [[String:Any]];badSplats[0]["radius"] = -1;badJuice["splats"]=badSplats
    var rejectedInk=false;do {try afterGoo.restore(JSONSerialization.data(withJSONObject:badJuice))}catch{rejectedInk=true}
    check(rejectedInk,"invalid saved splash geometry is rejected before drawing")
    runFlightVisitorTests {check($0,$1)}
    runEggSprayTests {check($0,$1)}
    print("\(checks) checks passed")
}
