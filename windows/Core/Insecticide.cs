using System;
using System.Collections.Generic;
using System.Linq;
namespace DesktopCritters.Core;
public sealed class SprayCloud {public V P;public double Age;}
public sealed partial class World {
 public List<SprayCloud> Sprays=new();public double SprayCooldown;
 public void Spray(V p){if(!Interactive||Paused||Result||SprayCooldown>0)return;SprayCooldown=.22;Sprays.Add(new SprayCloud{P=p});if(Sprays.Count>8)Sprays.RemoveAt(0);int count=PoisonBugs(p);Say(count==0?"喷过了，雾里没有虫。":"喷倒"+count+"只，按4用扫把清理。");}
 public int PoisonBugs(V p){var victims=Bugs.Where(b=>b.P.Distance(p)<90+Radius(b)*.45).ToArray();foreach(var b in victims)Kill(b,false,true);if(victims.Length>0)Record("杀虫剂：喷倒"+victims.Length+"只虫，尸体留待清扫");return victims.Length;}
}
