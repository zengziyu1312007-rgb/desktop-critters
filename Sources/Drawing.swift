import AppKit

enum Ink {
    static let cream = NSColor(hex:0xF7F4EB)
    static let forest = NSColor(hex:0x233B32)
    static let muted = NSColor(hex:0x819087)
    static let orange = NSColor(hex:0xE98043)
    static let mint = NSColor(hex:0x84CBB1)
    static let line = NSColor(hex:0xDDDCD0)
}
extension NSColor {
    convenience init(hex: Int, alpha: Double = 1) { self.init(srgbRed:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,alpha:alpha) }
}
func fillRound(_ r: CGRect,_ color: NSColor,_ radius: CGFloat = 12) {
    color.setFill(); NSBezierPath(roundedRect:r,xRadius:radius,yRadius:radius).fill()
}
func strokeRound(_ r: CGRect,_ color: NSColor,_ radius: CGFloat = 12,_ width: CGFloat = 1) {
    color.setStroke(); let p = NSBezierPath(roundedRect:r,xRadius:radius,yRadius:radius); p.lineWidth=width; p.stroke()
}
func label(_ text: String,_ x: CGFloat,_ y: CGFloat,_ size: CGFloat,_ color: NSColor,_ weight: NSFont.Weight = .regular, width: CGFloat = 400, align: NSTextAlignment = .left) {
    let style = NSMutableParagraphStyle(); style.alignment=align; style.lineBreakMode = .byTruncatingTail
    (text as NSString).draw(in:CGRect(x:x,y:y,width:width,height:size*1.65),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style])
}
func line(_ c: CGContext,_ points: [CGPoint],_ color: NSColor,_ width: CGFloat) {
    guard let first = points.first else { return }
    c.beginPath(); c.move(to:first); for p in points.dropFirst() { c.addLine(to:p) }
    c.setStrokeColor(color.cgColor); c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round); c.strokePath()
}
func ellipse(_ c: CGContext,_ r: CGRect,_ color: NSColor) { c.setFillColor(color.cgColor); c.fillEllipse(in:r) }
func shadedOval(_ c: CGContext,_ r: CGRect,_ light: NSColor,_ dark: NSColor) {
    c.saveGState(); c.addEllipse(in:r); c.clip()
    if let grad = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[light.cgColor,dark.cgColor] as CFArray,locations:[0,1]) {
        c.drawLinearGradient(grad,start:CGPoint(x:r.minX,y:r.minY),end:CGPoint(x:r.maxX,y:r.maxY),options:[])
    }
    c.restoreGState()
}

enum Creatures {
    static let roachSize: CGFloat = 1.25
    static let antSize: CGFloat = 0.65
    static let photoBody=loadBody("roach-body-photo")
    static let antPhotoBody=loadBody("ant-body-photo-v1")
    static func loadBody(_ name:String)->NSImage {
        guard let url=Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Textures"),
              let source=NSImage(contentsOf:url),
              let cg=source.cgImage(forProposedRect:nil,context:nil,hints:nil) else {
            fatalError("Missing bundled insect body texture: \(name)")
        }
        // Tight alpha bounds are calculated at load time; the original generated asset is preserved.
        let w=cg.width,h=cg.height
        var pixels=[UInt8](repeating:0,count:w*h*4)
        var minX=w,minY=h,maxX=0,maxY=0
        pixels.withUnsafeMutableBytes { raw in
            let context=CGContext(data:raw.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg,in:CGRect(x:0,y:0,width:w,height:h))
            let bytes=raw.bindMemory(to:UInt8.self)
            for y in 0..<h {for x in 0..<w where bytes[(y*w+x)*4+3]>16 {
                minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)
            }}
        }
        let bounds=CGRect(x:minX,y:h-1-maxY,width:maxX-minX+1,height:maxY-minY+1)
        let cropped=cg.cropping(to:bounds) ?? cg
        return NSImage(cgImage:cropped,size:NSSize(width:cropped.width,height:cropped.height))
    }
    // Skeletal parts are drawn at a fixed local scale, head toward +X.
    // The gait moves alternating tripods; antennas bend independently.
    static func roach(_ c: CGContext,phase: Double,flipped: Bool = false,scale: CGFloat = 1,alpha: CGFloat = 1,flight:RoachFlight?=nil) {
        c.saveGState(); c.scaleBy(x:scale*roachSize,y:scale*roachSize); c.setAlpha(alpha)
        if flight == nil {ellipse(c,CGRect(x:-28,y:-8,width:56,height:24),NSColor.black.withAlphaComponent(0.15))}
        let leg = NSColor(hex:0x61351D)
        for side in [-1.0,1.0] {
            for n in 0..<3 {
                let baseX = 15-Double(n)*10
                let swing = sin(phase+Double(n)*2.1+(side>0 ? 0 : Double.pi))*(flipped ? 5.5 : 3.7)
                let kneeX = baseX+Double(1-n)*8+swing
                let kneeY = side*(13+Double(n)*1.5)
                let footX = baseX+Double(1-n)*18-swing
                let footY = side*(23+Double(n)*1.4)
                let root=CGPoint(x:baseX,y:side*5),knee=CGPoint(x:kneeX,y:kneeY),foot=CGPoint(x:footX,y:footY)
                line(c,[root,knee],NSColor(hex:0x492616),2.2)
                line(c,[root,knee],NSColor(hex:0xAD642C),1.25)
                line(c,[knee,foot],leg,1.5)
                line(c,[CGPoint(x:kneeX,y:kneeY-side*0.25),CGPoint(x:footX,y:footY-side*0.25)],NSColor(hex:0xBF793C),0.6)
                // Fine tibial spines, tarsal segments and hooked feet follow the animated joints.
                for j in 1...5 {
                    let t=Double(j)/6, x=kneeX+(footX-kneeX)*t, y=kneeY+(footY-kneeY)*t
                    line(c,[CGPoint(x:x,y:y),CGPoint(x:x-2.1,y:y+side*(2.7-Double(j)*0.15))],NSColor(hex:0x34291C),0.45)
                }
                let toeX=footX+Double(1-n)*6, toeY=footY+side*3
                line(c,[foot,CGPoint(x:toeX,y:toeY),CGPoint(x:toeX+2,y:toeY-side*1.4)],leg,0.55)
            }
        }
        if let flight=flight {flyingWings(c,phase:phase,open:flight.open)}
        // The pronotum and wing casing are a photographic cutout, not painted ellipses.
        let body=photoBody, bodyHeight=52*body.size.height/body.size.width
        c.saveGState()
        if flipped {c.rotate(by:sin(phase*0.7)*0.10);c.scaleBy(x:1,y:-0.86)}
        body.draw(in:CGRect(x:-26,y:-bodyHeight/2,width:52,height:bodyHeight),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high.rawValue])
        c.restoreGState()
        for side in [-1.0,1.0] {
            let sway = sin(phase*0.31+side)*5
            for segment in 0..<18 {
                let t0=Double(segment)/18,t1=Double(segment+1)/18
                func antenna(_ t:Double)->CGPoint {CGPoint(x:24+43*t+sway*t*t,y:side*(3+8*t+(15+sway)*t*t))}
                line(c,[antenna(t0),antenna(t1)],NSColor(hex:segment%2==0 ? 0x7E482B : 0x483023),CGFloat(0.85-0.55*t0))
            }
            line(c,[CGPoint(x:-24,y:side*4),CGPoint(x:-30,y:side*7)],leg,1)
        }
        c.restoreGState()
    }
    static func ant(_ c: CGContext,phase: Double,scale: CGFloat = 1,alpha: CGFloat = 1,morph:Int=2) {
        c.saveGState(); c.scaleBy(x:scale*antSize,y:scale*antSize); c.setAlpha(alpha)
        if morph==0 {
            for n in 0..<6 {let x=Double(n)*4-14,y=sin(phase*0.5+Double(n)*0.35)*1.5;shadedOval(c,CGRect(x:x,y:y-4,width:7,height:8),NSColor(hex:0xE2D7BA),NSColor(hex:0x9D9278))}
            shadedOval(c,CGRect(x:8,y:-3,width:6,height:6),NSColor(hex:0xAB966E),NSColor(hex:0x68533C));c.restoreGState();return
        }
        let leg=NSColor(hex:0x302820)
        for side in [-1.0,1.0] {
            for n in 0..<3 {
                let baseX=2-Double(n)*2.2,swing=sin(phase+Double(n)*2.1+(side>0 ? 0 : Double.pi))*3
                let root=CGPoint(x:baseX,y:side*2)
                let knee=CGPoint(x:baseX+Double(1-n)*7+swing,y:side*(9+Double(n)))
                let foot=CGPoint(x:baseX+Double(1-n)*15-swing,y:side*(17-Double(n)))
                line(c,[root,knee,foot],leg,0.9)
                line(c,[root,knee],NSColor(hex:0x8A7763),0.35)
                line(c,[foot,CGPoint(x:foot.x-3,y:foot.y+side*1.6)],leg,0.4)
                for j in 1...3 {let t=Double(j)/4,px=knee.x+(foot.x-knee.x)*t,py=knee.y+(foot.y-knee.y)*t
                    line(c,[CGPoint(x:px,y:py),CGPoint(x:px-1,y:py+side*1.1)],NSColor(hex:0x655544),0.2)
                }
            }
        }
        let body=antPhotoBody,bodyHeight=40*body.size.height/body.size.width
        body.draw(in:CGRect(x:-20,y:-bodyHeight/2,width:40,height:bodyHeight),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high.rawValue])
        for side in [-1.0,1.0] {
            let sway=sin(phase*0.4+side)*1.4
            let root=CGPoint(x:13,y:side*3),elbow=CGPoint(x:23,y:side*(8+sway)),tip=CGPoint(x:31+sway,y:side*5)
            line(c,[root,elbow],leg,0.65);line(c,[elbow,tip],NSColor(hex:0x63523F),0.4)
            for j in 1...4 {let t=Double(j)/5;ellipse(c,CGRect(x:elbow.x+(tip.x-elbow.x)*t,y:elbow.y+(tip.y-elbow.y)*t,width:0.45,height:0.45),leg)}
        }
        c.restoreGState()
    }
    static func cookie(_ c: CGContext,portions: Int = 18,original: Int = 18,scale: CGFloat = 1) {
        guard portions>0 else {return}
        c.saveGState(); c.scaleBy(x:scale,y:scale)
        let r:CGFloat=18
        let eaten=Double(max(0,original-portions))/Double(max(1,original))*6
        // Subtract each bite independently: overlapping bites must never fill back in.
        for i in 0..<6 {
            let progress=min(1,max(0,eaten-Double(i)))
            if progress<=0 {continue}
            let a=Double(i)*Double.pi/3-0.5, radius=13*sqrt(progress)
            let cut=CGMutablePath();cut.addRect(CGRect(x:-40,y:-40,width:80,height:80))
            cut.addEllipse(in:CGRect(x:cos(a)*18-radius,y:sin(a)*18-radius,width:radius*2,height:radius*2))
            c.addPath(cut);c.clip(using:.evenOdd)
        }
        ellipse(c,CGRect(x:-r,y:-r+3,width:r*2,height:r*2),NSColor.black.withAlphaComponent(0.12))
        shadedOval(c,CGRect(x:-r,y:-r,width:r*2,height:r*2),NSColor(hex:0xEDD090),NSColor(hex:0xBD8A45))
        c.setStrokeColor(NSColor(hex:0xA16E35).cgColor);c.setLineWidth(0.8);c.strokeEllipse(in:CGRect(x:-r+1,y:-r+1,width:r*2-2,height:r*2-2))
        let dots:[(CGFloat,CGFloat)]=[(-0.5,-0.25),(0.2,-0.55),(0.45,0.2),(-0.2,0.4),(-0.05,-0.02)]
        for d in dots {ellipse(c,CGRect(x:d.0*r-1.5,y:d.1*r-1.5,width:3,height:3),NSColor(hex:0x735034))}
        c.restoreGState()
    }
    static func snack(_ c:CGContext,kind:Snack,portions:Int,original:Int,scale:CGFloat=1) {
        if kind == .cookie {cookie(c,portions:portions,original:original,scale:scale);return}
        c.saveGState();c.scaleBy(x:scale,y:scale)
        if kind == .pizza {pizza(c,portions:portions,original:original);c.restoreGState();return}
        let eaten=Double(max(0,original-portions))/Double(max(1,original))*7
        for i in 0..<7 {
            let progress=min(1,max(0,eaten-Double(i)))
            if progress<=0 {continue}
            let a=Double(i)*Double.pi*2/7, radius=15*sqrt(progress)
            let cut=CGMutablePath();cut.addRect(CGRect(x:-50,y:-50,width:100,height:100))
            cut.addEllipse(in:CGRect(x:cos(a)*20-radius,y:sin(a)*20-radius,width:radius*2,height:radius*2));c.addPath(cut);c.clip(using:.evenOdd)
        }
        ellipse(c,CGRect(x:-22,y:-12,width:44,height:35),NSColor.black.withAlphaComponent(0.12))
        if kind == .cake || kind == .banquet {
            fillRound(CGRect(x:-22,y:-18,width:44,height:38),NSColor(hex:0xBC7949),4)
            for n in 0..<95 {let x=Double((n*17)%42)-21,y=Double((n*13)%27)-7;ellipse(c,CGRect(x:x,y:y,width:0.9,height:0.7),NSColor(hex:n%2==0 ? 0x874D29 : 0xE3B17B,alpha:0.45))}
            fillRound(CGRect(x:-21,y:3,width:42,height:5),NSColor(hex:0xF9E8C2),1)
            fillRound(CGRect(x:-22,y:-20,width:44,height:13),NSColor(hex:0xF6DED2),5)
            for i in 0..<6 {ellipse(c,CGRect(x:-19+Double(i)*7,y:-12,width:7,height:10),NSColor(hex:0xF6DED2))}
            shadedOval(c,CGRect(x:-5,y:-25,width:10,height:10),NSColor(hex:0xE16B52),NSColor(hex:0x9B302B))
        } else if kind == .cheese {
            let p=CGMutablePath();p.move(to:CGPoint(x:-22,y:18));p.addLine(to:CGPoint(x:-16,y:-20));p.addLine(to:CGPoint(x:24,y:12));p.closeSubpath();c.addPath(p);c.setFillColor(NSColor(hex:0xE9B744).cgColor);c.fillPath()
            line(c,[CGPoint(x:-20,y:17),CGPoint(x:22,y:12)],NSColor(hex:0xBC862D),3)
            for d in [CGPoint(x:-9,y:8),CGPoint(x:-10,y:-8),CGPoint(x:5,y:7)] {ellipse(c,CGRect(x:d.x-3,y:d.y-2,width:6,height:5),NSColor(hex:0xC78E28))}
        } else {
            let p=CGMutablePath();p.move(to:CGPoint(x:0,y:23));p.addCurve(to:CGPoint(x:-17,y:-12),control1:CGPoint(x:-15,y:8),control2:CGPoint(x:-23,y:-3));p.addCurve(to:CGPoint(x:17,y:-12),control1:CGPoint(x:-12,y:-23),control2:CGPoint(x:12,y:-23));p.addCurve(to:CGPoint(x:0,y:23),control1:CGPoint(x:23,y:-3),control2:CGPoint(x:15,y:8));p.closeSubpath();c.addPath(p);c.setFillColor(NSColor(hex:0xC54D3D).cgColor);c.fillPath()
            for i in 0..<12 {let x=Double(i%3-1)*8,y=Double(i/3)*8-12;ellipse(c,CGRect(x:x,y:y,width:1.7,height:2.5),NSColor(hex:0xF3C57A))}
            for i in -1...1 {line(c,[CGPoint(x:0,y:-16),CGPoint(x:Double(i)*12,y:-23),CGPoint(x:Double(i)*8,y:-12)],NSColor(hex:0x5C7940),3)}
        }
        c.restoreGState()
    }
    static func bug(_ c:CGContext,_ b:Bug,alpha:Double=1,dead:Bool=false) {
        if CreatureFrames.draw(c,b,alpha:alpha,dead:dead) {return}
        if b.species == .ant {
            ant(c,phase:dead ? 0 : b.phase,alpha:alpha,morph:b.morph)
            return
        }
        roach(c,phase:dead ? 0 : b.phase,flipped:dead,alpha:alpha,flight:dead ? nil : b.flight)
        c.saveGState();c.scaleBy(x:roachSize,y:roachSize);c.setAlpha(alpha)
        if b.morph<2 {
            // Wingless, segmented nymph abdomen; adult photographic wings appear later.
            shadedOval(c,CGRect(x:-26,y:-9,width:43,height:18),NSColor(hex:b.morph==0 ? 0xB88A5D : 0x9C552E),NSColor(hex:0x482919))
            for n in 0..<6 {let x = -22+Double(n)*6;line(c,[CGPoint(x:x,y:-7),CGPoint(x:x+1,y:7)],NSColor(hex:0xD0A06B,alpha:0.62),0.7)}
        }
        // Adult photo texture stays exposed at every size: no fantasy plates, horns or gold trim.
        c.restoreGState()
    }
    static func outsider(_ c:CGContext,_ v:Invader,alpha:Double=1) {
        c.saveGState();c.setAlpha(alpha);c.rotate(by:v.angle)
        if v.kind == .centipede || v.kind == .snake || v.kind == .rat {visitorBody(c,v);c.restoreGState();return}
        if v.kind == .spider {
            for side in [-1.0,1.0] {for n in 0..<4 {
                let x=Double(n)*9-13,sway=sin(v.phase+Double(n)*1.8+side)*7
                let knee=CGPoint(x:x+Double(n-2)*13+sway,y:side*(25+Double(n%2)*5))
                let foot=CGPoint(x:x+Double(n-2)*25-sway,y:side*(55-Double(n%2)*8))
                line(c,[CGPoint(x:x,y:side*5),knee,foot],NSColor(hex:0x352B27),4)
                line(c,[CGPoint(x:x,y:side*5),knee,foot],NSColor(hex:0x756554),1.3)
                for j in 1...3 {let t=Double(j)/4;let px=knee.x+(foot.x-knee.x)*t,py=knee.y+(foot.y-knee.y)*t;line(c,[CGPoint(x:px,y:py),CGPoint(x:px-3,y:py+side*4)],NSColor(hex:0x46352C),0.8)}
            }}
            shadedOval(c,CGRect(x:-37,y:-20,width:46,height:40),NSColor(hex:0x71604C),NSColor(hex:0x25201D))
            shadedOval(c,CGRect(x:-4,y:-15,width:31,height:30),NSColor(hex:0x886D50),NSColor(hex:0x302820))
            for side in [-1.0,1.0] {line(c,[CGPoint(x:23,y:side*7),CGPoint(x:35,y:side*9),CGPoint(x:32,y:side*2)],NSColor(hex:0x9C8062),3)}
            for n in 0..<4 {ellipse(c,CGRect(x:19+Double(n%2)*5,y:Double(n/2)*8-6,width:3,height:3),NSColor(hex:0x191617))}
        } else {
            for side in [-1.0,1.0] {for n in 0..<3 {
                let x=Double(n)*16-18,sway=sin(v.phase+Double(n)*2)*5
                line(c,[CGPoint(x:x,y:side*10),CGPoint(x:x-12+sway,y:side*28),CGPoint(x:x-22,y:side*36)],NSColor(hex:0x444937),3)
            }}
            shadedOval(c,CGRect(x:-42,y:-28,width:69,height:56),NSColor(hex:0x8D9D56),NSColor(hex:0x263D29))
            line(c,[CGPoint(x:-36,y:0),CGPoint(x:19,y:0)],NSColor(hex:0x1F3023),2)
            for side in [-1.0,1.0] {line(c,[CGPoint(x:-29,y:side*13),CGPoint(x:9,y:side*20)],NSColor(hex:0xC4BD79,alpha:0.6),1.2)}
            shadedOval(c,CGRect(x:14,y:-23,width:32,height:46),NSColor(hex:0xA6A05F),NSColor(hex:0x38442B))
            line(c,[CGPoint(x:38,y:0),CGPoint(x:67,y:0),CGPoint(x:62,y:-12)],NSColor(hex:0x574C30),7)
            line(c,[CGPoint(x:40,y:-2),CGPoint(x:64,y:-2)],NSColor(hex:0xC9B984),2)
        }
        c.restoreGState()
    }
    static func broom(_ c:CGContext,swing:Double=0,scale:Double=1) {
        c.saveGState();c.scaleBy(x:scale,y:scale);c.rotate(by:-0.5+swing)
        line(c,[CGPoint(x:0,y:-4),CGPoint(x:0,y:-83)],NSColor(hex:0x6E442D),7)
        line(c,[CGPoint(x:-1.5,y:-6),CGPoint(x:-1.5,y:-82)],NSColor(hex:0xCE9B62),2.5)
        let head=CGMutablePath();head.move(to:CGPoint(x:-14,y:-4));head.addLines(between:[CGPoint(x:14,y:-4),CGPoint(x:26,y:28),CGPoint(x:-26,y:28)]);head.closeSubpath();c.addPath(head);c.setFillColor(NSColor(hex:0xD9B465).cgColor);c.fillPath()
        for n in -10...10 {let x=Double(n)*2.3;line(c,[CGPoint(x:x*0.55,y:-1),CGPoint(x:x,y:27+Double(abs(n)%3))],NSColor(hex:n%2==0 ? 0x9E7740 : 0xF0D590),1)}
        fillRound(CGRect(x:-15,y:-5,width:30,height:8),NSColor(hex:0x687C66),3)
        c.restoreGState()
    }
    static func pizza(_ c:CGContext,portions:Int,original:Int) {
        let eaten=Double(max(0,original-portions))/Double(max(1,original))*9
        for i in 0..<9 {
            let t=min(1,max(0,eaten-Double(i)));if t<=0 {continue}
            let side=i%2==0 ? -1.0 : 1.0,y=22-Double(i/2)*10,x=side*(28-y)*0.48,r=12*sqrt(t)
            let path=CGMutablePath();path.addRect(CGRect(x:-50,y:-50,width:100,height:110));path.addEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2));c.addPath(path);c.clip(using:.evenOdd)
        }
        let p=CGMutablePath();p.move(to:CGPoint(x:-27,y:-23));p.addQuadCurve(to:CGPoint(x:27,y:-23),control:CGPoint(x:0,y:-35));p.addLine(to:CGPoint(x:1,y:31));p.closeSubpath()
        c.addPath(p);c.setFillColor(NSColor(hex:0xAD612B).cgColor);c.fillPath()
        let cheese=CGMutablePath();cheese.move(to:CGPoint(x:-23,y:-20));cheese.addLine(to:CGPoint(x:23,y:-20));cheese.addLine(to:CGPoint(x:1,y:27));cheese.closeSubpath();c.addPath(cheese);c.setFillColor(NSColor(hex:0xF2BD53).cgColor);c.fillPath()
        let crust=CGMutablePath();crust.move(to:CGPoint(x:-26,y:-24));crust.addQuadCurve(to:CGPoint(x:26,y:-24),control:CGPoint(x:0,y:-34));c.addPath(crust);c.setStrokeColor(NSColor(hex:0xD59749).cgColor);c.setLineWidth(6);c.setLineCap(.round);c.strokePath()
        c.saveGState();c.addPath(cheese);c.clip()
        for n in 0..<90 {let x=Double((n*37)%53)-26,y=Double((n*19)%60)-27;ellipse(c,CGRect(x:x,y:y,width:Double(n%3)*0.4+0.5,height:0.7),NSColor(hex:n%3==0 ? 0xA9692C : 0xFFE2A1,alpha:0.55))}
        c.restoreGState()
        for n in 0..<18 {let x=Double(n)*2.8-24,y = -24-5*(1-pow(x/26,2));line(c,[CGPoint(x:x,y:y-1),CGPoint(x:x+1,y:y+1)],NSColor(hex:0xF4C87A,alpha:0.65),0.6)}
        for p in [CGPoint(x:-11,y:-14),CGPoint(x:11,y:-13),CGPoint(x:0,y:1),CGPoint(x:0,y:16)] {
            shadedOval(c,CGRect(x:p.x-5,y:p.y-5,width:10,height:10),NSColor(hex:0xB95735),NSColor(hex:0x923E26))
            for n in 0..<3 {ellipse(c,CGRect(x:p.x+Double(n%2)*3-2,y:p.y+Double(n/2)*4-2,width:1.5,height:1.3),NSColor(hex:0xE9BA7A))}
        }
        for n in 0..<7 {let x=Double(n%3-1)*9,y=Double(n/3)*10-16;line(c,[CGPoint(x:x,y:y),CGPoint(x:x+3,y:y+2)],NSColor(hex:0x617A3C),1)}
    }
    static func crumb(_ c:CGContext,scale:CGFloat) {
        c.saveGState();c.scaleBy(x:scale,y:scale)
        let p=CGMutablePath();p.move(to:CGPoint(x:-5,y:-3));p.addLines(between:[CGPoint(x:0,y:-5),CGPoint(x:5,y:-1),CGPoint(x:3,y:4),CGPoint(x:-3,y:3)]);p.closeSubpath()
        c.addPath(p);c.setFillColor(NSColor(hex:0xD4A568).cgColor);c.fillPath()
        line(c,[CGPoint(x:-4,y:-2),CGPoint(x:0,y:-4),CGPoint(x:4,y:-1)],NSColor(hex:0xF2D7A2),1)
        ellipse(c,CGRect(x:0,y:0,width:1.5,height:1.5),NSColor(hex:0x735034));c.restoreGState()
    }
    static func egg(_ c:CGContext,species:Species) {
        if species == .roach {
            ellipse(c,CGRect(x:-7,y:-2.4,width:14,height:6.5),NSColor.black.withAlphaComponent(0.13))
            shadedOval(c,CGRect(x:-7,y:-3.5,width:14,height:7),NSColor(hex:0xAD7945),NSColor(hex:0x59371D))
            line(c,[CGPoint(x:-5,y:-2.1),CGPoint(x:5,y:-2.1)],NSColor(hex:0xC29767),0.5)
            for n in -3...3 {
                let x=Double(n)*1.45
                line(c,[CGPoint(x:x,y:-1.7),CGPoint(x:x+0.35,y:2.1)],NSColor(hex:0x644326,alpha:0.7),0.35)
            }
        } else {
            ellipse(c,CGRect(x:-1.8,y:-0.4,width:3.6,height:2),NSColor.black.withAlphaComponent(0.1))
            shadedOval(c,CGRect(x:-1.8,y:-1,width:3.6,height:2),NSColor(hex:0xF5F0DE),NSColor(hex:0xC4BEAB))
        }
    }
    static func slipper(_ c: CGContext,scale: CGFloat = 1) {
        c.saveGState(); c.scaleBy(x:scale,y:scale)
        fillRound(CGRect(x:-14,y:-33,width:28,height:62),NSColor(hex:0xBC6141),13)
        fillRound(CGRect(x:-12,y:-35,width:24,height:61),NSColor(hex:0xF0A075),11)
        fillRound(CGRect(x:-12,y:-21,width:24,height:23),NSColor(hex:0xF6C399),7)
        for n in 0..<4 { line(c,[CGPoint(x:-8,y:8+n*4),CGPoint(x:8,y:8+n*4)],NSColor(hex:0xDA865D),0.7) }
        c.restoreGState()
    }
}

func drawNest(_ c: CGContext,at p: V,roach: Bool,score: Int) {
    c.saveGState(); c.translateBy(x:p.x,y:p.y)
    let accent = roach ? Ink.orange : Ink.mint
    ellipse(c,CGRect(x:-37,y:-21,width:74,height:42),accent.withAlphaComponent(0.16))
    for i in 0..<7 {
        let a = Double(i)*0.9
        ellipse(c,CGRect(x:cos(a)*31-3,y:sin(a)*17-2,width:6,height:4),NSColor(hex:roach ? 0x98734F : 0x879481,alpha:0.7))
    }
    shadedOval(c,CGRect(x:-24,y:-13,width:48,height:26),NSColor(hex:0x8E8977),NSColor(hex:0x30382B))
    ellipse(c,CGRect(x:-17,y:-8,width:34,height:16),NSColor(hex:0x1F2922))
    c.restoreGState()
}

func drawJuice(_ c:CGContext,_ s:JuiceSplat,airborne:Bool=false,alpha:Double=1) {
    c.saveGState();c.translateBy(x:s.p.x,y:s.p.y);c.rotate(by:s.angle)
    let r=s.radius,spread=min(1,s.age/0.23),wet=1-min(1,s.age/4)*0.25
    if !airborne {
        // Soft edge, irregular sticky body and a lighter wet interior.
        let pool=CGMutablePath();var points:[CGPoint]=[]
        for n in 0..<28 {
            let a=Double(n)*Double.pi*2/28
            let wobble=0.92+sin(Double(n)*2.3+Double(s.bugID%17))*0.14
            points.append(CGPoint(x:cos(a)*r*1.75*wobble,y:sin(a)*r*0.76*wobble))
        }
        let first=points[0],last=points.last!
        pool.move(to:CGPoint(x:(first.x+last.x)/2,y:(first.y+last.y)/2))
        for n in points.indices {let p=points[n],next=points[(n+1)%points.count];pool.addQuadCurve(to:CGPoint(x:(p.x+next.x)/2,y:(p.y+next.y)/2),control:p)}
        pool.closeSubpath()
        c.saveGState();let k=0.28+spread*0.72;c.scaleBy(x:k,y:k)
        c.setAlpha(alpha*0.24);c.setFillColor(NSColor(hex:0x3A2815).cgColor);c.addPath(pool);c.fillPath()
        c.setAlpha(alpha*0.9);c.scaleBy(x:0.97,y:0.94);c.addPath(pool);c.clip()
        if let liquid=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[NSColor(hex:0xD8C57F).cgColor,NSColor(hex:0xAE8D45).cgColor,NSColor(hex:0x755324).cgColor] as CFArray,locations:[0,0.58,1]) {
            c.saveGState();c.scaleBy(x:1.9,y:0.8)
            c.drawRadialGradient(liquid,startCenter:CGPoint(x:-r*0.1,y:-r*0.2),startRadius:0,endCenter:.zero,endRadius:r,options:[.drawsAfterEndLocation]);c.restoreGState()
        }
        for n in 0..<5 {
            let a=Double(n)*2.4+Double(s.bugID%9),size=r*(0.035+Double(n%3)*0.025)
            shadedOval(c,CGRect(x:cos(a)*r*1.1-size,y:sin(a)*r*0.5-size*0.5,width:size*2,height:size),NSColor(hex:0xEEDBA0,alpha:0.65),NSColor(hex:0x927332,alpha:0.4))
        }
        c.setAlpha(alpha*0.76*wet)
        let reflection=CGMutablePath();reflection.move(to:CGPoint(x:-r*1.1,y:-r*0.31));reflection.addCurve(to:CGPoint(x:-r*0.12,y:-r*0.42),control1:CGPoint(x:-r*0.8,y:-r*0.5),control2:CGPoint(x:-r*0.48,y:-r*0.44))
        c.addPath(reflection);c.setStrokeColor(NSColor(hex:0xFFF0C7).cgColor);c.setLineWidth(max(0.7,r*0.036));c.strokePath()
        c.restoreGState()
    }
    for (n,d) in s.drops.enumerated() {
        let t=min(1,max(0,s.age/d.flight))
        if airborne != (t<1) {continue}
        let p=s.offset(of:d,at:s.age),k=d.radius*(0.3+min(1,t*4)*0.7)
        c.saveGState();c.translateBy(x:p.x,y:p.y);c.rotate(by:atan2(d.offset.y,d.offset.x))
        let elongation=t<1 ? 1.8 : 1.15
        if airborne && t<0.65 && n%5==0 {
            c.setAlpha(alpha*(1-t)*0.6);line(c,[CGPoint(x:-k*4,y:0),.zero],NSColor(hex:0xA18340),k*0.5)
        }
        let blob=CGMutablePath();blob.move(to:CGPoint(x:-k*(airborne ? 3.4 : 1.9),y:0))
        blob.addCurve(to:CGPoint(x:k*elongation,y:0),control1:CGPoint(x:-k*0.6,y:-k*0.4),control2:CGPoint(x:k*0.6,y:-k*1.4))
        blob.addCurve(to:CGPoint(x:-k*(airborne ? 3.4 : 1.9),y:0),control1:CGPoint(x:k*1.3,y:k*1.5),control2:CGPoint(x:-k*0.7,y:k*0.45));blob.closeSubpath()
        c.setAlpha(alpha*0.92);c.addPath(blob);c.clip()
        if let liquid=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[NSColor(hex:0xE5D393).cgColor,NSColor(hex:0xAE8E43).cgColor,NSColor(hex:0x72511F).cgColor] as CFArray,locations:[0,0.4,1]) {
            c.drawLinearGradient(liquid,start:CGPoint(x:0,y:-k),end:CGPoint(x:k*0.3,y:k),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        }
        c.setAlpha(alpha*wet*0.9);ellipse(c,CGRect(x:-k*0.1,y:-k*0.58,width:k*0.8,height:k*0.26),NSColor(hex:0xFFF1C2))
        c.restoreGState()
    }
    c.restoreGState()
}

func drawArena(_ world: World,in c: CGContext,showHint: Bool = true) {
    c.saveGState()
    c.setAllowsAntialiasing(true)
    if world.filming {
        c.setStrokeColor(Ink.muted.withAlphaComponent(0.45).cgColor); c.setLineWidth(1)
        c.setLineDash(phase:0,lengths:[5,7]); c.stroke(world.field.insetBy(dx:-17,dy:-17)); c.setLineDash(phase:0,lengths:[])
    }
    for t in world.trails { ellipse(c,CGRect(x:t.p.x-1.4,y:t.p.y-1.4,width:2.8,height:2.8),Ink.mint.withAlphaComponent(t.life/4*0.3)) }
    drawNest(c,at:world.roachNest,roach:true,score:world.roachScore)
    drawNest(c,at:world.antNest,roach:false,score:world.antScore)
    for f in world.foods {
        c.saveGState(); c.translateBy(x:f.p.x,y:f.p.y); c.rotate(by:f.angle)
        if f.original<=5 {Creatures.crumb(c,scale:1)} else {Creatures.snack(c,kind:f.snack,portions:f.portions,original:f.original,scale:world.snackScale(f.snack))}; c.restoreGState()
    }
    for egg in world.eggs {
        c.saveGState()
        if world.eggOccluded(egg) {
            for place in world.shelters {
                let clip=CGMutablePath();clip.addRect(CGRect(x:0,y:0,width:world.width,height:world.height));clip.addRect(place.rect)
                c.addPath(clip);c.clip(using:.evenOdd)
            }
        }
        let shown=egg.shownPoint;c.translateBy(x:shown.x,y:shown.y)
        let emerging=0.15+0.85*min(1,egg.emission*2);c.scaleBy(x:emerging,y:1)
        // Stable orientation, small proportions and a contact shadow; no HUD around eggs.
        c.rotate(by:Double(egg.id % 17)*0.19-1.4)
        Creatures.egg(c,species:egg.species)
        c.restoreGState()
    }
    for stain in world.splats {drawJuice(c,stain)}
    for corpse in world.corpses {
        let b = corpse.bug
        if CharacterLibrary.shared.customRendering(for:b.species) {
            c.saveGState();c.translateBy(x:b.p.x,y:b.p.y);c.scaleBy(x:world.scale(for:b),y:world.scale(for:b));CharacterArt.draw(c,bug:b,clock:world.clock,dead:true,alpha:0.64);c.restoreGState();continue
        }
        c.saveGState(); c.translateBy(x:b.p.x,y:b.p.y); c.rotate(by:b.angle)
        let crushed=world.splats.first{$0.bugID==b.id && $0.crushed}
        let press=crushed.map{max(0,1-$0.age/0.22)} ?? 0
        c.scaleBy(x:world.scale(for:b)*(1+press*0.28),y:world.scale(for:b)*(0.55-press*0.28))
        Creatures.bug(c,b,alpha:crushed == nil ? 0.55 : 0.78,dead:true)
        c.restoreGState()
    }
    if world.archivedCorpses > 0 {
        for n in 0..<6 {
            ellipse(c,CGRect(x:world.width/2+Double(n%3)*5-8,y:world.height-50+Double(n/3)*3,width:8,height:4),NSColor(hex:0x514638,alpha:0.6))
        }
    }
    for cloud in world.sprays {Creatures.sprayMist(c,cloud)}
    for b in world.bugs where b.flight != nil {
        let k=world.scale(for:b),lift=b.flight!.lift
        ellipse(c,CGRect(x:b.p.x-30*k+lift*0.35,y:b.p.y+lift,width:60*k,height:16*k),NSColor.black.withAlphaComponent(0.09))
    }
    for b in world.bugs.sorted(by:{if ($0.flight != nil) != ($1.flight != nil) {return $0.flight == nil};return $0.p.y<$1.p.y}) {
        c.saveGState()
        var shown=b.p
        if let target=b.fightTarget, b.fightTime>0 {
            let elapsed=0.6-b.fightTime
            let jab=elapsed<0.16 ? sin(elapsed/0.16*Double.pi)*(b.species == .roach ? 13.0 : 8.0) : -sin(min(1,(elapsed-0.16)/0.3)*Double.pi)*3
            shown=shown+(target-b.p).unit*jab
        }
        c.translateBy(x:shown.x,y:shown.y)
        if (b.hitTime ?? 0)>0 {c.translateBy(x:sin(world.clock*65+Double(b.id))*2,y:cos(world.clock*50)*1.5)}
        if b.id == world.grabbedID {
            ellipse(c,CGRect(x:-34,y:13,width:68,height:16),NSColor.black.withAlphaComponent(0.13))
            c.translateBy(x:0,y:-12); c.scaleBy(x:1.13,y:1.13)
        }
        let avatar=CharacterLibrary.shared.customRendering(for:b.species)
        if !avatar {c.rotate(by:b.angle + (b.fightTime>0 ? sin(world.clock*35+Double(b.id))*0.22 : 0))}
        let breathing=1+sin(max(0,(b.bitePulse ?? 0))/0.55*Double.pi)*0.07+((b.layTime ?? 0)>0 ? sin(world.clock*9)*0.035 : 0)
        c.scaleBy(x:world.scale(for:b)*breathing,y:world.scale(for:b)*breathing)
        if avatar {CharacterArt.draw(c,bug:b,clock:world.clock)}
        else {Creatures.bug(c,b,alpha:0.73+0.27*b.growth)}
        if (b.webTime ?? 0)>0 {
            for n in -2...2 {
                line(c,[CGPoint(x:-25,y:Double(n)*5-12),CGPoint(x:27,y:Double(n)*5+12)],NSColor(white:0.92,alpha:0.65),0.5)
                line(c,[CGPoint(x:Double(n)*9-10,y:-18),CGPoint(x:Double(n)*9+10,y:18)],NSColor(white:0.92,alpha:0.55),0.5)
            }
        }
        if b.cargo>0 && !avatar { c.saveGState(); c.translateBy(x:b.species == .roach ? 34*Creatures.roachSize : 21*Creatures.antSize,y:0); Creatures.crumb(c,scale:b.species == .roach ? 1.1 : 0.5); c.restoreGState() }
        c.restoreGState()
    }
    for v in world.invaders {
        c.saveGState();c.translateBy(x:v.p.x,y:v.p.y)
        if v.dead {c.scaleBy(x:1,y:0.5)}
        Creatures.outsider(c,v,alpha:v.dead ? 0.5 : 1);c.restoreGState()
    }
    for sweep in world.sweeps {
        let t=min(1,sweep.age/sweep.duration),ease=1-pow(1-t,3)
        for var stain in sweep.stains {
            stain.p=stain.p+V(x:ease*90,y: -ease*35);stain.age=max(1,stain.age)
            c.saveGState();c.translateBy(x:stain.p.x,y:stain.p.y);c.scaleBy(x:1-ease*0.6,y:1-ease*0.85);c.translateBy(x: -stain.p.x,y: -stain.p.y)
            drawJuice(c,stain,alpha:1-t);c.restoreGState()
        }
        for b in sweep.bodies {
            if CharacterLibrary.shared.customRendering(for:b.species) {
                c.saveGState();c.translateBy(x:b.p.x+ease*90,y:b.p.y-ease*35);c.rotate(by:ease);c.scaleBy(x:world.scale(for:b)*(1-ease*0.75),y:world.scale(for:b)*(1-ease*0.75));CharacterArt.draw(c,bug:b,clock:world.clock,dead:true,alpha:(1-t)*0.6);c.restoreGState();continue
            }
            c.saveGState();c.translateBy(x:b.p.x+ease*90,y:b.p.y-ease*35);c.rotate(by:b.angle+ease*1.1)
            c.scaleBy(x:world.scale(for:b)*(1-ease*0.75),y:world.scale(for:b)*0.55*(1-ease*0.75))
            Creatures.bug(c,b,alpha:(1-t)*0.55,dead:true);c.restoreGState()
        }
        for e in sweep.eggs {c.saveGState();c.translateBy(x:e.p.x+ease*90,y:e.p.y-ease*35);c.setAlpha(1-t);Creatures.egg(c,species:e.species);c.restoreGState()}
        for v in sweep.invaders {c.saveGState();c.translateBy(x:v.p.x+ease*90,y:v.p.y-ease*35);c.scaleBy(x:1-ease*0.7,y:0.5*(1-ease*0.7));Creatures.outsider(c,v,alpha:(1-t)*0.55);c.restoreGState()}
        c.saveGState();c.translateBy(x:sweep.p.x-35+ease*85,y:sweep.p.y);c.setAlpha(1-t*t);Creatures.broom(c,swing:sin(t*Double.pi)*0.7);c.restoreGState()
    }
    for fight in world.fights {
        if CharacterArt.fight(c,fight,world:world) {continue}
        let t=fight.age/fight.duration
        let direction=(fight.to-fight.from).unit
        let impact=fight.from+(fight.to-fight.from)*0.62
        c.saveGState();c.translateBy(x:impact.x,y:impact.y)
        c.rotate(by:atan2(direction.y,direction.x));c.scaleBy(x:fight.size,y:fight.size)
        if fight.style == .web {
            c.setAlpha((1-t)*0.8)
            for n in -3...3 {let y=Double(n)*8;line(c,[CGPoint(x:-25,y:0),CGPoint(x:25,y:y)],NSColor(white:0.94,alpha:0.8),0.8)}
            for n in 1...3 {let x=Double(n)*15-20;line(c,[CGPoint(x:x,y:-20),CGPoint(x:x+7,y:0),CGPoint(x:x,y:20)],NSColor(white:0.94,alpha:0.75),0.7)}
        } else if fight.style == .ram {
            for n in -1...1 {let y=Double(n)*11;line(c,[CGPoint(x:-30-t*15,y:y),CGPoint(x:-8,y:y)],NSColor(hex:0xCDB98F,alpha:(1-t)*0.75),2)}
            let arc=CGMutablePath();arc.move(to:CGPoint(x:8,y:-25));arc.addQuadCurve(to:CGPoint(x:8,y:25),control:CGPoint(x:32+t*12,y:0));c.addPath(arc);c.setStrokeColor(NSColor(hex:0xF1DFB2,alpha:1-t).cgColor);c.setLineWidth(2);c.strokePath()
        } else if fight.style == .pincer || fight.style == .swarm {
            for side in [-1.0,1.0] {let path=CGMutablePath();path.move(to:CGPoint(x:-18,y:side*20));path.addQuadCurve(to:CGPoint(x:9,y:side*(2+t*10)),control:CGPoint(x:21,y:side*22));c.addPath(path);c.setStrokeColor(NSColor(hex:0xE3D0A0,alpha:1-t).cgColor);c.setLineWidth(fight.style == .swarm ? 1.2 : 2.2);c.strokePath()}
        }
        // Brief impact rays, a claw swipe, and small dust chips; no labels or damage numbers.
        if t<0.38 {
            let strength=sin(min(1,t/0.38)*Double.pi)
            c.setAlpha(strength*0.85)
            let reach=fight.heavy ? 19.0 : 12.0
            for n in -2...2 {
                let a=Double(n)*0.6
                line(c,[CGPoint(x:cos(a)*4,y:sin(a)*4),CGPoint(x:cos(a)*reach,y:sin(a)*reach)],NSColor(hex:0xFFE8B7),fight.heavy ? 2.2 : 1.4)
            }
            let slash=CGMutablePath();slash.move(to:CGPoint(x:-11,y:-11));slash.addQuadCurve(to:CGPoint(x:10,y:12),control:CGPoint(x:16,y:-5))
            c.addPath(slash);c.setStrokeColor(NSColor(hex:0xEEE2C8,alpha:0.85).cgColor);c.setLineWidth(fight.swarm ? 2 : 1.2);c.strokePath()
        }
        c.setAlpha(max(0,1-t)*0.55)
        for n in 0..<5 {
            let a=Double(n)*2.4+Double(fight.attacker%7)
            let distance=6+t*(fight.heavy ? 32 : 22)
            let size=(fight.heavy ? 3.0 : 2.0)*(1-t*0.5)
            ellipse(c,CGRect(x:cos(a)*distance,y:sin(a)*distance+t*t*8,width:size,height:size),NSColor(hex:0xB49C74))
        }
        c.restoreGState()
    }
    if world.tool == .spray && world.interactive,let p=world.pointer {c.saveGState();c.translateBy(x:p.x-65,y:p.y+35);Creatures.aerosol(c);c.restoreGState()}
    if world.tool == .shelter && world.interactive,let p=world.pointer {
        c.saveGState();c.setLineDash(phase:0,lengths:[3,4]);c.setStrokeColor(Ink.forest.withAlphaComponent(0.4).cgColor);c.setLineWidth(1)
        c.stroke(EggShelter(p:p).rect);c.restoreGState()
    }
    for stain in world.splats {drawJuice(c,stain,airborne:true)}
    for p in world.puffs {
        let color = p.kind == 4 ? NSColor(hex:0xB7A181) : (p.kind == 3 ? Ink.mint : (p.kind == 1 ? NSColor.white : Ink.orange))
        ellipse(c,CGRect(x:p.p.x-2,y:p.p.y-2,width:4,height:4),color.withAlphaComponent(p.life/p.lifetime))
    }
    if world.interactive, let p = world.pointer {
        c.saveGState(); c.translateBy(x:p.x,y:p.y)
        if world.tool == .roachEgg || world.tool == .antEgg {
            c.setAlpha(0.75); Creatures.egg(c,species:world.tool == .roachEgg ? .roach : .ant)
        } else if world.tool == .slipper {
            c.setAlpha(0.85); c.rotate(by:-0.35); Creatures.slipper(c,scale:0.85)
        } else if world.tool == .clean {
            c.setAlpha(0.85);Creatures.broom(c)
        } else if world.tool == .food {
            c.setAlpha(0.7); Creatures.snack(c,kind:world.selectedSnack,portions:world.selectedSnack.servings,original:world.selectedSnack.servings,scale:world.snackScale(world.selectedSnack))
        }
        c.restoreGState()
    }
    if let p = world.slap, world.slapTime>0 {
        c.saveGState(); c.translateBy(x:p.x,y:p.y)
        let progress = 1-world.slapTime/0.38
        c.setAlpha(1-progress)
        c.setStrokeColor(Ink.orange.cgColor); c.setLineWidth(2)
        let radius = 30+progress*55
        c.strokeEllipse(in:CGRect(x:-radius,y:-radius,width:radius*2,height:radius*2))
        c.rotate(by:-0.5); Creatures.slipper(c,scale:1.1); c.restoreGState()
    }
    c.restoreGState()
}

final class ArenaView: NSControl {
    let world: World
    var onEscape: (() -> Void)?
    var onTool: ((Tool) -> Void)?
    var onPause: (() -> Void)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }
    init(world: World,frame: CGRect) {
        self.world=world; super.init(frame:frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("互动桌面：点击投食，按 1 至 7 切换工具，Esc 回到工作")
    }
    required init?(coder:NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool {true}
    override func accessibilityPerformPress() -> Bool {
        let center=world.pointer ?? V(x:world.width*0.5,y:world.height*0.6)
        world.press(center); world.release(); needsDisplay=true
        return true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        c.clear(bounds)
        if world.interactive {
            // A fully clear macOS window is not hit-testable in its empty pixels.
            // Battle mode gently dims the desktop and provides a reliable event surface.
            c.setFillColor(NSColor.black.withAlphaComponent(0.12).cgColor); c.fill(bounds)
        }
        drawArena(world,in:c)
    }
    func point(_ event:NSEvent) -> V { let p = convert(event.locationInWindow,from:nil); return V(x:p.x,y:p.y) }
    override func mouseDown(with e:NSEvent) { world.press(point(e)); CharacterLibrary.shared.observe(in:world,at:point(e)); needsDisplay=true }
    override func mouseDragged(with e:NSEvent) { world.drag(point(e)); needsDisplay=true }
    override func mouseUp(with e:NSEvent) { world.release() }
    override func rightMouseDown(with e:NSEvent) { onEscape?() }
    override func mouseMoved(with e:NSEvent) { world.pointer = point(e); needsDisplay=true }
    override func keyDown(with e:NSEvent) {
        if e.keyCode == 53 { onEscape?(); return }
        if e.characters == " " { onPause?(); return }
        if let chars = e.characters, let number = Int(chars), let tool = Tool(rawValue:number-1) { onTool?(tool); return }
        super.keyDown(with:e)
    }
}
