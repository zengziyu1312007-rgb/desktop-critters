using System;
namespace DesktopCritters.Core;
public sealed partial class World {
 public string LeftPetId="roach",RightPetId="ant",LeftPetName="蟑螂",RightPetName="蚂蚁";
 public string PetId(Species side)=>side==Species.Roach?LeftPetId:RightPetId;
 public string PetName(Species side)=>side==Species.Roach?LeftPetName:RightPetName;
 public string TeamName(Species side)=>(side==Species.Roach?"左队 · ":"右队 · ")+PetName(side);
 public bool Upright(Species side)=>PetId(side)!="roach"&&PetId(side)!="ant"&&PetId(side)!="rat";
 public string PetText(string text){if(LeftPetId=="roach"&&RightPetId=="ant")return text;foreach(var word in new[]{"蟑螂帮","巨型蟑螂","小蟑螂","蟑螂","厚背成蟑","成蟑"})text=text.Replace(word,"{LEFT_TEAM}");foreach(var word in new[]{"蚂蚁军团","巨型蚂蚁","小蚂蚁","蚂蚁","巨颚兵蚁","小工蚁","幼蚁","成蚁"})text=text.Replace(word,"{RIGHT_TEAM}");return text.Replace("{LEFT_TEAM}",TeamName(Species.Roach)).Replace("{RIGHT_TEAM}",TeamName(Species.Ant));}
 public string PetMorphTitle(Bug b)=>PetId(b.Species)==(b.Species==Species.Roach?"roach":"ant")?b.MorphTitle:new[]{"初生","幼小","成年","强壮","巨型"}[b.Morph]+PetName(b.Species);
}
