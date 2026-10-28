using System;
using System.Collections.Generic;
using System.Linq;
namespace DesktopCritters.Core;
public sealed class EggShelter {public V P {get;set;} public bool Contains(V p)=>Math.Abs(p.X-P.X)<32&&Math.Abs(p.Y-P.Y)<24;}
public sealed partial class World {
 public List<EggShelter> Shelters=new();
 public void MarkShelter(V point){var p=Safe(point);var old=Shelters.FirstOrDefault(x=>x.P.Distance(p)<35);if(old!=null){Shelters.Remove(old);Say("这处藏卵位置已取消。");return;}if(Shelters.Count>=6){Say("已有六处藏卵位置，点原位置可取消。");return;}Shelters.Add(new EggShelter{P=p});Say("藏卵处已记住，附近成虫会来产卵；再点取消。");}
 public V? ShelterGoal(Bug b){if(!b.Breeder||!b.Adult||b.Flight!=null||(b.Species==Species.Roach?RoachBirth:AntBirth)>=6)return null;var place=Shelters.OrderBy(p=>p.P.Distance(b.P)).FirstOrDefault();return place==null?null:SafeBug(place.P-new V(Radius(b)+33,0),b);}
 public void OrientForLaying(Bug b){var place=Shelters.OrderBy(p=>p.P.Distance(b.P)).FirstOrDefault();if(place!=null&&place.P.Distance(b.P)<Radius(b)+100)b.Angle=Math.Atan2(b.P.Y-place.P.Y,b.P.X-place.P.X);}
 public Egg EmittedEgg(Bug b,int id){var d=new V(Math.Cos(b.Angle),Math.Sin(b.Angle));double k=Scale(b);var start=b.P-d*((b.Species==Species.Roach?20:8)*k);var end=Safe(b.P-d*((b.Species==Species.Roach?40:20)*k));var place=Shelters.OrderBy(p=>p.P.Distance(b.P)).FirstOrDefault();if(place!=null&&place.P.Distance(b.P)<Radius(b)+100)end=place.P+new V(0,8);return new Egg{Id=id,Species=b.Species,P=end,HatchTime=b.Species==Species.Roach?28:22,Brood=b.Species==Species.Roach?3:1,Generation=b.Generation+1,LayStart=start,LayAge=0,ParentId=b.Id};}
 public V HatchPoint(Egg e){var place=Shelters.FirstOrDefault(p=>p.Contains(e.P));return Safe((place==null?e.P:place.P+new V(45,27))+new V(Rng(-6,6),Rng(-6,6)));}
 public bool EggOccluded(Egg e)=>e.Emission>.8&&Shelters.Any(p=>p.Contains(e.P))&&!(Tool==Tool.Observe&&Watched==e.Id);
}
