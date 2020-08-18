import options, tables
import neverwinter/[gff, resman, tlk, twoda]
import helper

type
  Creature = object
    name, resref, tag: string
    palette, palette_full: string
    palette_id: int
    cr, cr_adjust, hp: int
    level: int
    class1: string
    class1_id: int
    class1_level: int
    class2: string
    class2_id: int
    class2_level: int
    class3: string
    class3_id: int
    class3_level: int
    faction: string
    faction_id: int
    parent_faction: string
    parent_faction_id: int
    race: string
    race_id: int
    gender: string
    gender_id: int
    alignment: string
    alignment_lawful_chaotic, alignment_good_evil: int
    natural_ac: int
    str, dex, con, int, wis, cha: int
    lootable, disarmable, is_immortal, no_perm_death, plot, interruptable: int
    walk_rate: int
    conversation: string
    comment: string

  ClassInfo = object
    name1, name2, name3: string
    id1, id2, id3: int
    level1, level2, level3: int

  AlignmentRange = range[0 .. 100]

  Alignment = object
    lawfulChaotic, goodEvil: AlignmentRange

proc toClassInfo(classList: GffList, classes2da: TwoDA, dlg: SingleTlk, tlk: Option[SingleTlk]): ClassInfo =
  result.id1 = classList[0]["Class", GffInt]
  result.name1 = classes2da[result.id1, "Name"].get.tlkText(dlg, tlk)
  result.level1 = classList[0]["ClassLevel", GffShort]
  if classList.len >= 2:
    result.id2 = classList[1]["Class", GffInt]
    result.name2 = classes2da[result.id2, "Name"].get.tlkText(dlg, tlk)
    result.level2 = classList[1]["ClassLevel", GffShort]
  if classList.len == 3:
    result.id3 = classList[2]["Class", GffInt]
    result.name3 = classes2da[result.id3, "Name"].get.tlkText(dlg, tlk)
    result.level3 = classList[2]["ClassLevel", GffShort]

proc name(utc: GffRoot, dlg: SingleTlk, tlk: Option[SingleTlk]): string =
  result = utc["FirstName", GffCExoLocString].getStr(dlg, tlk)
  let last = utc["LastName", GffCExoLocString].getStr(dlg, tlk)
  if last.len > 0:
    result &= " " & last

proc name(a: Alignment): string =
  let lc = case a.lawfulChaotic
  of 70 .. 100: "L"
  of 31 .. 69: "N"
  of 0 .. 30: "C"
  let ge = case a.goodEvil
  of 70 .. 100: "G"
  of 31 .. 69: "N"
  of 0 .. 30: "E"
  if lc == ge: "TN" else: lc & ge

proc creatureList*(list: seq[ResRef], rm: ResMan, dlg: SingleTlk, tlk: Option[SingleTlk]): seq[Creature] =
  let
    isMod = rm[newResRef("module", "ifo".getResType)].isSome
    classes2da = rm.get2da("classes")
    racialtypes = rm.get2da("racialtypes")
    gender = rm.get2da("gender")
    factionInfo = if isMod: rm.getGffRoot("repute", "fac").toFactionInfo else: FactionInfo()
  var
    crs: Table[string, int]
    palcusInfo: PalcusInfo
  if isMod:
    let creaturepalcus = rm.getGffRoot("creaturepalcus", "itp")["MAIN", GffList]
    for c in creaturepalcus.flatten:
      if not c.hasField("RESREF", GffResRef): continue
      crs[$c["RESREF", GffResRef]] = c["CR", GffFloat].toInt
    palcusInfo = creaturepalcus.toPalcusInfo(dlg, tlk)
  for rr in list:
    let
      utc = rm.getGffRoot(rr)
      paletteId = utc["PaletteID", 0.GffByte].int
      factionId = utc["FactionID", 0.GffWord].int
      factionName = factionInfo.names.getOrDefault(factionId, "")
      parentFactionId = factionInfo.parents.getOrDefault(factionId, -1)
      parentFactionName = factionInfo.names.getOrDefault(parentFactionId, "")
      classInfo = utc["ClassList", GffList].toClassInfo(classes2da, dlg, tlk)
      alignment = Alignment(lawfulChaotic: utc["LawfulChaotic", GffByte], goodEvil: utc["GoodEvil", GffByte])
    result &= Creature(
      name: utc.name(dlg, tlk),
      resref: rr.resRef,
      tag: utc["Tag", ""],
      palette: palcusInfo.getOrDefault(paletteId).name,
      paletteFull: palcusInfo.getOrDefault(paletteId).full,
      paletteId: paletteId,
      cr: crs.getOrDefault(rr.resRef, -1),
      crAdjust: utc["CRAdjust", 0.GffInt],
      hp: utc["MaxHitPoints", 0.GffShort],
      class1: classInfo.name1,
      class1Id: classInfo.id1,
      class1Level: classInfo.level1,
      class2: classInfo.name2,
      class2Id: classInfo.id2,
      class2Level: classInfo.level2,
      class3: classInfo.name3,
      class3Id: classInfo.id3,
      class3Level: classInfo.level3,
      level: classInfo.level1 + classInfo.level2 + classInfo.level3,
      faction: factionName,
      factionId: factionId,
      parentFaction: parentFactionName,
      parentFactionId: parentFactionId,
      race: racialtypes[utc["Race", 0.GffByte], "Name"].get.tlkText(dlg, tlk),
      raceId: utc["Race", 0.GffByte].int,
      gender: gender[utc["Gender", 0.GffByte], "Name"].get.tlkText(dlg, tlk),
      genderId: utc["Gender", 0.GffByte].int,
      alignment: alignment.name,
      alignmentLawfulChaotic: alignment.lawfulChaotic,
      alignmentGoodEvil: alignment.goodEvil,
      naturalAc: utc["NaturalAC", 0.GffByte].int,
      str: utc["Str", 0.GffByte].int,
      dex: utc["Dex", 0.GffByte].int,
      con: utc["Con", 0.GffByte].int,
      int: utc["Int", 0.GffByte].int,
      wis: utc["Wis", 0.GffByte].int,
      cha: utc["Cha", 0.GffByte].int,
      lootable: utc["Lootable", 0.GffByte].int,
      disarmable: utc["Disarmable", 0.GffByte].int,
      isImmortal: utc["IsImmortal", 0.GffByte].int,
      noPermDeath: utc["NoPermDeath", 0.GffByte].int,
      plot: utc["Plot", 0.GffByte].int,
      interruptable: utc["Interruptable", 0.GffByte].int,
      walkRate: utc["WalkRate", 0.GffInt],
      conversation: $utc["Conversation", GffResRef],
      comment: utc["Comment", ""],
    )
