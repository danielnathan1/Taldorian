# hero_factory.gd
class_name HeroFactory

static func make_team() -> Array[Hero]:
	return [
		HeroPoppy.new(),
		HeroPoppy.new(),
		HeroPoppy.new(),
	]