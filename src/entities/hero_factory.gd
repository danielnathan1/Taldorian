# hero_factory.gd
class_name HeroFactory

static func make_team() -> Array[Hero]:
	return [
		HeroPoppy.new(),
		HeroHakai.new(),
		HeroPoppy.new(),
	]
