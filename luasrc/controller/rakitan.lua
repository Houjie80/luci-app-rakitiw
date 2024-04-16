module("luci.controller.rakitan", package.seeall)
function index()
entry({"admin","services","rakitan"}, template("rakitan"), _("Modem Rakitan"), 7).leaf=true
end
