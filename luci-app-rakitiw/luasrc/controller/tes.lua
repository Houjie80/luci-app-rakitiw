module("luci.controller.tes", package.seeall)
function index()
entry({"admin","vpn","tes"}, template("tes"), _("Modem tes"), 7).leaf=true
end
