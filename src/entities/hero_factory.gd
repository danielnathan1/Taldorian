# hero_factory.gd
class_name HeroFactory

static func make_team() -> Array[Hero]:
	return [
		HeroPoppy.new(),
		HeroHakai.new(),
		HeroIrena.new(),
		HeroIeldor.new(),
		HeroNissin.new(),
		HeroValkar.new(),
		HeroNox.new(),
		HeroRelicar.new(),
	]
