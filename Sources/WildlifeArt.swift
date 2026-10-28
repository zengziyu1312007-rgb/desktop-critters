import AppKit

extension Creatures {
    static func aerosol(_ c:CGContext,firing:Double=0) {
        let kick=sin(max(0,min(1,firing))*Double.pi)
        c.saveGState();c.translateBy(x:-kick*7,y:kick*3);c.rotate(by:-kick*0.055)
        ellipse(c,CGRect(x:-40,y:71,width:82,height:15),NSColor.black.withAlphaComponent(0.16))
        // Wide outlined can, bright enough to read against both light and dark desktops.
        fillRound(CGRect(x:-37,y:-60,width:74,height:139),NSColor(hex:0x273A31),20)
        fillRound(CGRect(x:-33,y:-56,width:66,height:131),NSColor(hex:0xFFD43D),17)
        fillRound(CGRect(x:-28,y:-53,width:13,height:122),NSColor(hex:0xFFF18A,alpha:0.82),7)
        fillRound(CGRect(x:23,y:-51,width:7,height:117),NSColor(hex:0xE7A728),4)
        ellipse(c,CGRect(x:-31,y:-66,width:62,height:19),NSColor(hex:0xF6E8B8))
        strokeRound(CGRect(x:-31,y:-66,width:62,height:19),NSColor(hex:0x273A31),10,3)
        fillRound(CGRect(x:-14,y:-85+kick*3,width:29,height:24),NSColor(hex:0x24352D),6)
        fillRound(CGRect(x:-22,y:-94+kick*3,width:75,height:25),NSColor(hex:0xD94532),7)
        strokeRound(CGRect(x:-22,y:-94+kick*3,width:75,height:25),NSColor(hex:0x273A31),7,3)
        fillRound(CGRect(x:-14,y:-90+kick*3,width:56,height:6),NSColor(hex:0xFF8464),3)
        fillRound(CGRect(x:45,y:-90+kick*3,width:14,height:16),NSColor(hex:0x273A31),4)
        ellipse(c,CGRect(x:49,y:-86+kick*3,width:6,height:8),NSColor(hex:0xA4DAC5))
        fillRound(CGRect(x:-28,y:-32,width:56,height:94),NSColor(hex:0xFFF9DF),9)
        strokeRound(CGRect(x:-28,y:-32,width:56,height:94),NSColor(hex:0xC93B2A),9,2.5)
        label("杀虫剂",-27,-50,10,NSColor(hex:0xA82B24),.heavy,width:54,align:.center)
        for (i,word) in ["敌","敌","畏"].enumerated() {
            label(word,-22,-27+Double(i)*27,23,NSColor(hex:0xBA2E25),.heavy,width:44,align:.center)
        }
        for n in 0..<5 {line(c,[CGPoint(x:-25+Double(n)*11,y:68),CGPoint(x:-19+Double(n)*11,y:68)],NSColor(hex:0x273A31),3)}
        // A few nozzle glints make the idle tool readable before the first click.
        if firing>0 {
            for n in -2...2 {line(c,[CGPoint(x:63,y:-82),CGPoint(x:82+Double(abs(n))*7,y:-82+Double(n)*7)],NSColor(hex:0xE7FF9E,alpha:firing),2)}
        }
        c.restoreGState()
    }
    static func aerosolTool(_ c:CGContext,at p:V,width:Double,height:Double,firing:Double=0) {
        let x=min(max(43,p.x-105),max(43,width-65)),y=min(max(99,p.y+82),max(99,height-85))
        c.saveGState();c.translateBy(x:x,y:y);aerosol(c,firing:firing);c.restoreGState()
    }
    static func sprayMist(_ c:CGContext,_ cloud:SprayCloud) {
        let t=min(1,cloud.age/1.2),fade=(1-t)*0.4
        // The bright pressure jet and expanding droplets read as a spray, not a quiet fog.
        if cloud.age<0.3 {
            let jet=1-cloud.age/0.3
            for n in -2...2 {line(c,[CGPoint(x:cloud.p.x-50,y:cloud.p.y),CGPoint(x:cloud.p.x+50+Double(2-abs(n))*22,y:cloud.p.y+Double(n)*(9+t*14))],NSColor(hex:n==0 ? 0xF8FFE1 : 0xC3E28C,alpha:jet*0.78),n==0 ? 5 : 2)}
        }
        for n in 0..<30 {
            let a=Double(n)*2.39996,reach=(20+Double(n%7)*10)*(0.3+t*1.4),r=9+Double(n%4)*5
            ellipse(c,CGRect(x:cloud.p.x+cos(a)*reach-r,y:cloud.p.y+sin(a)*reach*0.7-t*24-r,width:r*2,height:r*2),NSColor(hex:n%3==0 ? 0xB9D97B : 0xE7F2CC,alpha:fade))
            if n%3==0 {ellipse(c,CGRect(x:cloud.p.x+cos(a)*reach,y:cloud.p.y+sin(a)*reach*0.6,width:3,height:3),NSColor(hex:0xF5FFD8,alpha:(1-t)*0.7))}
        }
    }
    static func flyingWings(_ c:CGContext,phase:Double,open:Double) {
        guard open>0 else {return}
        for side in [-1.0,1.0] {
            c.saveGState()
            c.scaleBy(x:1,y:side*open*(0.75+sin(phase*1.9)*0.22))
            // Translucent hindwings fan out from the thorax; thin veins stay attached to the hinge.
            let wing=CGMutablePath();wing.move(to:CGPoint(x:12,y:3))
            wing.addCurve(to:CGPoint(x:-47,y:29),control1:CGPoint(x:-2,y:11),control2:CGPoint(x:-53,y:5))
            wing.addCurve(to:CGPoint(x:-23,y:47),control1:CGPoint(x:-50,y:48),control2:CGPoint(x:-36,y:53))
            wing.addCurve(to:CGPoint(x:12,y:3),control1:CGPoint(x:2,y:36),control2:CGPoint(x:18,y:14));wing.closeSubpath()
            c.addPath(wing);c.setFillColor(NSColor(hex:0xCDB37E,alpha:0.5).cgColor);c.fillPath()
            c.addPath(wing);c.setStrokeColor(NSColor(hex:0x705030,alpha:0.65).cgColor);c.setLineWidth(0.55);c.strokePath()
            for n in 0..<10 {
                let t=Double(n)/9
                line(c,[CGPoint(x:11,y:4),CGPoint(x:-40+t*22,y:15+t*31)],NSColor(hex:0x7B6542,alpha:0.43),0.38)
                line(c,[CGPoint(x:-20+t*17,y:12+t*14),CGPoint(x:-35+t*23,y:17+t*23)],NSColor(hex:0x8D7048,alpha:0.32),0.3)
            }
            // Lifted leathery forewing, reflecting the same brown palette as the photograph.
            let cover=CGMutablePath();cover.move(to:CGPoint(x:13,y:2));cover.addCurve(to:CGPoint(x:-33,y:20),control1:CGPoint(x:2,y:16),control2:CGPoint(x:-24,y:26));cover.addQuadCurve(to:CGPoint(x:13,y:2),control:CGPoint(x:-34,y:4))
            c.addPath(cover);c.setFillColor(NSColor(hex:0x81502C,alpha:0.85).cgColor);c.fillPath()
            line(c,[CGPoint(x:10,y:4),CGPoint(x:-23,y:17)],NSColor(hex:0xD3A567,alpha:0.6),0.8)
            c.restoreGState()
        }
    }
    static func visitorBody(_ c:CGContext,_ v:Invader) {
        if v.kind == .centipede {
            for n in stride(from:15,through:0,by:-1) {
                let x=35-Double(n)*8,y=sin(v.phase*0.55-Double(n)*0.58)*8,r=7.5-Double(n)*0.18
                for side in [-1.0,1.0] {
                    let wave=sin(v.phase-Double(n)*0.75+side)*5
                    line(c,[CGPoint(x:x,y:y+side*r*0.6),CGPoint(x:x-5+wave,y:y+side*(r+9)),CGPoint(x:x-12+wave,y:y+side*(r+14))],NSColor(hex:0x9A522A),1.6)
                    line(c,[CGPoint(x:x,y:y+side*r*0.5),CGPoint(x:x-5+wave,y:y+side*(r+9))],NSColor(hex:0xD29851),0.6)
                }
                shadedOval(c,CGRect(x:x-6,y:y-r,width:13,height:r*2),NSColor(hex:0x9B6335),NSColor(hex:0x3B2D22))
                line(c,[CGPoint(x:x-2,y:y-r*0.65),CGPoint(x:x+3,y:y-r*0.65)],NSColor(hex:0xD7AB6C,alpha:0.5),0.6)
            }
            shadedOval(c,CGRect(x:31,y:-11,width:22,height:22),NSColor(hex:0xB66B39),NSColor(hex:0x542B1D))
            for side in [-1.0,1.0] {
                line(c,[CGPoint(x:49,y:side*5),CGPoint(x:63,y:side*10),CGPoint(x:76,y:side*(11+sin(v.phase*0.4)*3))],NSColor(hex:0x8E673D),0.75)
                line(c,[CGPoint(x:51,y:side*4),CGPoint(x:59,y:side*6),CGPoint(x:57,y:0)],NSColor(hex:0x44231B),2)
            }
        } else if v.kind == .snake {
            // An articulated taper gives a moving S-curve and a visible coil before the strike.
            let coil=v.cooldown>0.7 ? 1.0 : 0.4
            for n in stride(from:39,through:0,by:-1) {
                let t=Double(n)/39,x=25-t*176,y=sin(t*9-v.phase*0.35)*((18+t*16)*coil),r=10*(1-t*0.8)
                shadedOval(c,CGRect(x:x-r,y:y-r,width:r*2.4,height:r*2),NSColor(hex:0x939064),NSColor(hex:0x3D4832))
                if n%3==0 {ellipse(c,CGRect(x:x-2,y:y-r*0.45,width:4,height:r*0.9),NSColor(hex:0x3A3D2A,alpha:0.72))}
            }
            shadedOval(c,CGRect(x:17,y:-12,width:34,height:24),NSColor(hex:0xAC9E6A),NSColor(hex:0x465136))
            for side in [-1.0,1.0] {ellipse(c,CGRect(x:40,y:side*7-1.5,width:3,height:3),NSColor(hex:0xD6C177));ellipse(c,CGRect(x:41,y:side*7-1,width:1,height:2),NSColor(hex:0x171D15))}
            if sin(v.phase*0.4)>0.4 {line(c,[CGPoint(x:49,y:0),CGPoint(x:64,y:0),CGPoint(x:69,y:-3)],NSColor(hex:0x9E4C42),0.8);line(c,[CGPoint(x:64,y:0),CGPoint(x:69,y:3)],NSColor(hex:0x9E4C42),0.8)}
        } else if v.kind == .rat {
            let tail=(0...20).map{n->CGPoint in let t=Double(n)/20;return CGPoint(x:-40-t*104,y:sin(t*5+v.phase*0.2)*15+t*12)}
            line(c,tail,NSColor(hex:0xAE8976),4);line(c,tail,NSColor(hex:0xD0AB95),1.1)
            for side in [-1.0,1.0] {for x in [-20.0,22.0] {let step=sin(v.phase+(x<0 ? .pi : 0))*5;shadedOval(c,CGRect(x:x-9+step,y:side*24-5,width:19,height:9),NSColor(hex:0xB59B86),NSColor(hex:0x70564A))}}
            shadedOval(c,CGRect(x:-47,y:-29,width:85,height:58),NSColor(hex:0x8B8170),NSColor(hex:0x49443D))
            for n in 0..<42 {let x=Double(n%9)*8-38,y=Double(n/9)*10-20;line(c,[CGPoint(x:x,y:y),CGPoint(x:x-5,y:y+sin(Double(n))*2)],NSColor(hex:n%2==0 ? 0xB0A48F : 0x5B5347,alpha:0.45),0.55)}
            for side in [-1.0,1.0] {shadedOval(c,CGRect(x:18,y:side*18-11,width:22,height:22),NSColor(hex:0x948370),NSColor(hex:0x4D443C));ellipse(c,CGRect(x:23,y:side*18-7,width:13,height:14),NSColor(hex:0xBA9985))}
            shadedOval(c,CGRect(x:16,y:-20,width:47,height:40),NSColor(hex:0x9A8D77),NSColor(hex:0x5B5145))
            for side in [-1.0,1.0] {ellipse(c,CGRect(x:43,y:side*10-2,width:5,height:4),NSColor(hex:0x171716));ellipse(c,CGRect(x:44,y:side*10-1,width:1,height:1),NSColor.white);for n in 0..<3 {line(c,[CGPoint(x:55,y:side*5),CGPoint(x:75+Double(n)*5,y:side*(8+Double(n)*6))],NSColor(hex:0xD7CDB9,alpha:0.8),0.55)}}
            ellipse(c,CGRect(x:59,y:-3,width:7,height:6),NSColor(hex:0xAD8372))
            if v.stolen>0 {crumb(c,scale:1.1)}
        }
    }
}
