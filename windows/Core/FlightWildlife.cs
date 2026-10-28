using System;
using System.Linq;
namespace DesktopCritters.Core;
public sealed class RoachFlight {
 public V Start,C1,C2,End;public double Elapsed,Duration=3,Height=45;
 public double Progress=>Math.Clamp(Elapsed/Duration,0,1);
 public double Lift=>Math.Sin(Progress*Math.PI)*Height;
 public double Open=>Math.Min(1,Math.Min(Progress/.12,(1-Progress)/.16));
 public V Point(double t){double u=1-t;return Start*(u*u*u)+C1*(3*u*u*t)+C2*(3*u*t*t)+End*(t*t*t);}
 public V Tangent(double t){double u=1-t;return(C1-Start)*(3*u*u)+(C2-C1)*(6*u*t)+(End-C2)*(3*t*t);}
}
public static class VisitorRules {
 public static string Name(InvaderKind k)=>new[]{"游猎蜘蛛","抢粮甲虫","游猎蜈蚣","伏击蛇","抢粮老鼠"}[(int)k];
 public static double Health(InvaderKind k)=>new[]{95d,150,115,190,210}[(int)k];
 public static double Speed(InvaderKind k)=>new[]{60d,60,94,66,108}[(int)k];
 public static double Cadence(InvaderKind k)=>new[]{2.3,1.8,.72,2.6,1.4}[(int)k];
 public static double Damage(InvaderKind k)=>new[]{1.4,2,1.1,4.8,2.4}[(int)k];
 public static bool Raider(InvaderKind k)=>k==InvaderKind.Beetle||k==InvaderKind.Rat;
 public static double Reach(InvaderKind k)=>k==InvaderKind.Snake?105:k==InvaderKind.Rat?82:64;
 public static string Introduction(InvaderKind k)=>new[]{"蜘蛛来了，会吐丝缠住虫群。","甲虫来了，正冲向食物。","蜈蚣贴地游走，正在连续追咬。","蛇盘住了，下一下会突然扑咬。","老鼠来抢粮，虫群要被冲散了。"}[(int)k];
}
public sealed partial class World {
 private readonly Random flightRandom=new(253209);
 private double FlightRandom(double a,double b)=>a+flightRandom.NextDouble()*(b-a);
 public bool BeginFlight(Bug b,V? source=null){if(Paused||Result||b.Species!=Species.Roach||!b.Adult||b.Flight!=null||b.LayTime>0||b.Web>0||b.Id==Grabbed||Bugs.Count(x=>x.Flight!=null)>=3)return false;
  double angle=FlightRandom(-Math.PI,Math.PI);var direction=source.HasValue?(b.P-source.Value).Unit:new V(Math.Cos(angle),Math.Sin(angle));if(direction.Length<.1)direction=new V(1,-.4).Unit;var end=SafeBug(b.P+direction*FlightRandom(310,620),b);if(end.Distance(b.P)<90)end=SafeBug(new V(Width-b.P.X,Height-b.P.Y),b);if(end.Distance(b.P)<=45)return false;var span=end-b.P;var side=new V(-span.Unit.Y,span.Unit.X)*FlightRandom(-160,160);
  b.Flight=new RoachFlight{Start=b.P,C1=SafeBug(b.P+span*.28+side,b),C2=SafeBug(b.P+span*.7-side*.5,b),End=end,Duration=FlightRandom(2.3,3.8)+b.Bulk*.8,Height=Math.Min(80,35+Scale(b)*7)};b.FlightWait=FlightRandom(18,42);b.Opponent=null;b.Hit=0;return true;
 }
 public int ScareRoaches(V? source=null){if(Paused||Result){Say("先继续运行，再惊飞蟑螂。");return 0;}int count=0;foreach(var b in Bugs.OrderBy(b=>source.HasValue?b.P.Distance(source.Value):-b.Bulk).ToArray()){if(source.HasValue&&b.P.Distance(source.Value)>Radius(b)+250)continue;if(BeginFlight(b,source))count++;if(count>=3)break;}if(!source.HasValue)Say(count>0?"蟑螂惊飞了，展开翅膀绕飞后落地。":"等成蟑挣脱蛛丝后再试。");if(count>0)Record("蟑螂惊飞："+count+"只成蟑离地避让，随后落回桌面");return count;}
 public bool Fly(Bug b,double dt){var f=b.Flight;if(f==null)return false;f.Elapsed=Math.Min(f.Duration,f.Elapsed+dt);double t=f.Progress;var direction=f.Tangent(t);if(direction.Length>.01)b.Angle=Math.Atan2(direction.Y,direction.X);b.P=SafeBug(f.Point(t),b);b.Phase+=dt*90;b.Opponent=null;if(t>=1){b.Flight=null;b.P=SafeBug(f.End,b);b.Wander=b.P;b.WanderTime=0;b.Cooldown=Math.Max(b.Cooldown,.65);}return true;}
 public void StepVisitors(double dt){InvasionTimer-=dt;if(InvasionTimer<=0&&Bugs.Count>=30)Summon((InvaderKind)(invaderSerial%5));foreach(var v in Invaders.Where(v=>!v.Dead).ToArray()){v.Age+=dt;v.Cooldown-=dt;if(v.Age>38){v.P+=(new V(Width+180,-180)-v.P).Unit*(dt*160);if(v.Age>42){Record(VisitorRules.Name(v.Kind)+"撤离，抢走"+v.Stolen+"份口粮");Invaders.Remove(v);}continue;}
  var targets=Bugs.Where(b=>b.Flight==null&&b.Id!=Grabbed).OrderBy(b=>b.P.Distance(v.P)).ToArray();var food=Foods.Where(f=>f.Portions>0).OrderBy(f=>f.P.Distance(v.P)).FirstOrDefault();var goal=VisitorRules.Raider(v.Kind)&&food!=null?food.P:targets.FirstOrDefault()?.P??new V(Width/2,Height/2);var d=goal-v.P;v.Angle=Math.Atan2(d.Y,d.X);v.Phase+=dt*(v.Kind==InvaderKind.Centipede?18:10);bool winding=v.Kind==InvaderKind.Centipede||v.Kind==InvaderKind.Snake;var motion=(d.Unit+(winding?new V(-d.Unit.Y,d.Unit.X)*Math.Sin(v.Phase*.45)*.55:V.Zero)).Unit;bool lunge=v.Cooldown<.4&&(v.Kind==InvaderKind.Snake||v.Kind==InvaderKind.Beetle);double speed=v.Kind==InvaderKind.Snake&&v.Cooldown>.7&&d.Length<220?12:lunge?225:VisitorRules.Speed(v.Kind);if(d.Length>45)v.P=Safe(v.P+motion*(dt*speed));if(v.Cooldown>0)continue;
  int strikes=0,limit=v.Kind==InvaderKind.Snake?1:v.Kind==InvaderKind.Centipede?2:5;foreach(var b in targets){double range=b.P.Distance(v.P);if(range>Radius(b)+VisitorRules.Reach(v.Kind)+26)continue;if(range<Radius(b)+VisitorRules.Reach(v.Kind)&&strikes<limit){b.Health-=VisitorRules.Damage(v.Kind);b.Hit=.3;if(v.Kind==InvaderKind.Spider)b.Web=2.8;else b.P=SafeBug(b.P+(b.P-v.P).Unit*(v.Kind==InvaderKind.Rat?48:v.Kind==InvaderKind.Snake?30:15),b);Fights.Add(new Fight{From=v.P,To=b.P,Style=v.Kind==InvaderKind.Spider?Attack.Web:v.Kind==InvaderKind.Snake?Attack.Pincer:v.Kind==InvaderKind.Centipede?Attack.Bite:Attack.Ram,Size=v.Kind==InvaderKind.Rat?2.5:1.8});strikes++;}if(b.Adult){v.Health-=1.8*(1+b.Bulk*7);Fights.Add(new Fight{From=b.P,To=v.P,Style=b.Bulk>.4?Attack.Ram:Attack.Pincer});}if(b.Health<=0)Kill(b,false);}
  if(VisitorRules.Raider(v.Kind)&&food!=null&&food.P.Distance(v.P)<FoodRadius(food)+60){int amount=Math.Min(v.Kind==InvaderKind.Rat?48:24,food.Portions);food.Portions-=amount;v.Stolen+=amount;}v.Cooldown=VisitorRules.Cadence(v.Kind);if(v.Dead)Record(VisitorRules.Name(v.Kind)+"被虫群击退，留下残骸");
 }if(Fights.Count>64)Fights.RemoveRange(0,Fights.Count-64);}
}
