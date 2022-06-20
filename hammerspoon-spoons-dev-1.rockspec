rockspec_format = "3.0"
package = "hammerspoon-spoons"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/kfischer-okarin/hammerspoon-spoons.git"
}
description = {
   homepage = "https://github.com/kfischer-okarin/hammerspoon-spoons",
   license = "MIT"
}
build = {
   type = "builtin",
   modules = {}
}
test = {
   type = "busted",
}
test_dependencies = {
   "busted ~> 2"
}
