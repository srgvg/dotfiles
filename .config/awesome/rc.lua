
------------------------------------------------------------------------------
-- awesome libraries----------------------------------------------------------
------------------------------------------------------------------------------
require("awful")
require("awful.autofocus")
require("awful.rules")
require("beautiful")
require("naughty")
require("debian.menu")
require("vicious")


------------------------------------------------------------------------------
-- Base config & vars --------------------------------------------------------
------------------------------------------------------------------------------
naughty.config.presets.normal.opacity = 0.7
naughty.config.presets.low.opacity = 0.7
naughty.config.presets.critical.opacity = 0.7
modkey = "Mod4"

config = {}
config.home     = os.getenv("HOME")
config.path    	= awful.util.getdir("config")
config.terminal = "terminator"
config.hostname = awful.util.pread('uname -n'):gsub('\n', '')
config.browser 	= "google-chrome"
config.editor = os.getenv("EDITOR") or "editor"
config.editor_cmd = config.terminal .. " -e " .. config.editor

if      config.hostname == "goldorak" then
        config.pasink = "0"
elseif  config.hostname == "cyberlab" then
        config.pasink = "1"
else
        config.pasink = "0"
end

-- Table of layouts to cover with awful.layout.inc, order matters. -----------
config.layouts = {
    awful.layout.suit.tile,
    --awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    --awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal --,
    --awful.layout.suit.spiral,
    --awful.layout.suit.spiral.dwindle,
    --awful.layout.suit.max,
    --awful.layout.suit.max.fullscreen,
    --awful.layout.suit.magnifier,
    --awful.layout.suit.floating
}
layouts = config.layouts

-- Create cache directory
os.execute("test -d " .. awful.util.getdir("cache") ..
           " || mkdir -p " .. awful.util.getdir("cache"))


------------------------------------------------------------------------------
-- Themes --------------------------------------------------------------------
------------------------------------------------------------------------------
theme_name = "zenburn"
beautiful.init(config.path .. "/themes/" .. theme_name .. "/theme.lua")
  -- default lsystem location /usr/share/awesome/themes/default/theme.lua



------------------------------------------------------------------------------
-- Simple function to load additional LUA files from rc/. --------------------
------------------------------------------------------------------------------
function loadrc(name, mod)
   local success
   local result

   -- Which file? In rc/ or in lib/?
   local path = awful.util.getdir("config") .. "/" ..
      (mod and "lib" or "rc") ..
      "/" .. name .. ".lua"

   -- If the module is already loaded, don't load it again
   if mod and package.loaded[mod] then return package.loaded[mod] end

   -- Execute the RC/module file
   success, result = pcall(function() return dofile(path) end)
   if not success then
      naughty.notify({ title = "Error while loading an RC file",
                       text = "When loading `" .. name ..
                          "`, got the following error:\n" .. result,
                       preset = naughty.config.presets.critical
                     })
      return print("E: error loading RC file '" .. name .. "': " .. result)
   end

   -- Is it a module?
   if mod then
      return package.loaded[mod]
   end

   return result
end


------------------------------------------------------------------------------
-- Load Modules --------------------------------------------------------------
------------------------------------------------------------------------------
loadrc("errors")
loadrc("xrun")

------------------------------------------------------------------------------
-- Tags ----------------------------------------------------------------------
------------------------------------------------------------------------------
tags = {}
for s = 1, screen.count() do
    if s == 1 then
    	tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s,
                        { layouts[1],    -- 1
                          layouts[1],    -- 2
                          layouts[1],    -- 3
                          layouts[1],    -- 4
                          layouts[1],    -- 5
                          layouts[1],    -- 6
                          layouts[1],    -- 7
                          layouts[3],    -- 8
                          layouts[2]})   -- 9
    else
    	tags[s] = awful.tag({ 1 }, s, layouts[3])
    end
end
-- }}}


------------------------------------------------------------------------------
-- Menu ----------------------------------------------------------------------
------------------------------------------------------------------------------
--[[
myawesomemenu = {
   { "manual", config.terminal .. " -e man awesome" },
   { "edit config", config.editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "Applications", debian.menu.Debian_menu.Debian },
                                    { "open terminal", config.terminal }
                                  }
                        })
--]]
mymainmenu = awful.menu({ items = {
	{ "Applications", debian.menu.Debian_menu.Debian },
	{ "Shutdown", "gnome-session-quit --power-off"},
	{ "Logout", "gnome-session-quit --logout --force" },
	{ "Suspend", config.home .. "/bin/lock-suspend" };
			} })

mylauncher = awful.widget.launcher({ image = image(beautiful.awesome_icon),
                                     menu = mymainmenu })

------------------------------------------------------------------------------
-- Wibox ---------------------------------------------------------------------
------------------------------------------------------------------------------
-- clock widget
datewidget = awful.widget.textclock({ align = "right" }, " %a %d %b | %H:%M:%S ", 1)
-- memory widget
memwidget = widget({ type = "textbox" })
vicious.register(memwidget, vicious.widgets.mem, "$1%", 15)
-- system tray widget
mysystray = widget({ type = "systray" })

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, awful.tag.viewnext),
                    awful.button({ }, 5, awful.tag.viewprev)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt({ layout = awful.widget.layout.horizontal.leftright })
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.label.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(function(c)
                                              return awful.widget.tasklist.label.currenttags(c, s)
                                          end, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })
    -- Add widgets to the wibox - order matters
    mywibox[s].widgets = {
        {
            mylauncher,
            mytaglist[s],
            mypromptbox[s],
            layout = awful.widget.layout.horizontal.leftright
        },
        mylayoutbox[s],
	datewidget,
	memwidget,
	-- systray only possible on one screen
        s == 1 and mysystray or nil,
        mytasklist[s],
        layout = awful.widget.layout.horizontal.rightleft
    }

end

------------------------------------------------------------------------------
-- Quake Console -------------------------------------------------------------
------------------------------------------------------------------------------
local quake = loadrc("quake", "vbe/quake")
local quakeconsole = {}
for s = 1, screen.count() do
   quakeconsole[s] = quake({ terminal = "urxvtcd --perl-lib " .. config.path .. "/lib/rxvt",
                             height = 0.4,
                             screen = s })
end

------------------------------------------------------------------------------
-- Key and Button Bindings ---------------------------------------------------
------------------------------------------------------------------------------
-- Mouse bindings
root.buttons(awful.util.table.join(
    --awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
    ))

-- Key bindings
keys = {}
keys.global = awful.util.table.join(

    -- PrtScr
    awful.key({                   }, "Print", false, function() 
        awful.util.spawn_with_shell("/usr/bin/scrot --select ~/Downloads/$(date +%Y%m%d%H%M%S).png") end),

    -- Ctrl-Alt-L - lock screen
    awful.key({ "Mod1", "Control" }, "l", function ()
	    					awful.util.spawn("/usr/bin/gnome-screensaver-command -l ") end),
    -- enter - launch terminal
    awful.key({ modkey,           }, "Return", function ()
	    					awful.util.spawn(config.terminal)         end),
    awful.key({ "Mod1", "Alt"     }, "Return", function ()
	    					quakeconsole[mouse.screen]:toggle()       end),
    awful.key({ modkey, "Control" }, "Return", function ()
	    					awful.util.spawn("gnome-terminal")        end),
    -- c - launch calculator
    awful.key({ modkey            }, "c",      function ()
                                                awful.util.spawn("gnome-calculator")      end),
    -- e - launch nautilus -- !! # why does awesome crash when this is defined?
    awful.key({ modkey            }, "e",     function ()
                                                awful.util.spawn("nautilus")              end),
    -- Ctrl r - restart awesome
    awful.key({ modkey, "Control" }, "r",      awesome.restart),
    awful.key({ modkey, "Shift"   }, "r",      function()
                                                 awful.util.spawn("awstartapps")              end),
    -- a or w - launch menu
    awful.key({ modkey,           }, "w",      function ()
	                             mymainmenu:show({keygrabber=true, coords={x=0,y=0} }) end),
    awful.key({ modkey,           }, "a",      function ()
	    			     mymainmenu:show({keygrabber=true, coords={x=0,y=0} }) end),
    -- Home/End - switch screens
    awful.key({ modkey,           }, "#110",  function () awful.screen.focus_relative( -1) end),
    awful.key({ modkey,           }, "#115",  function () awful.screen.focus_relative(  1) end),
    -- Page PgUp/Down - switch tags
    awful.key({ modkey,           }, "#112",  awful.tag.viewprev                              ),
    awful.key({ modkey,           }, "#117",  awful.tag.viewnext                              ),
    -- Left/Right - switch tags - interferes with some (Gnome?) Super-Right
    --awful.key({ modkey,           }, "Left",  awful.tag.viewprev                              ),
    --awful.key({ modkey,           }, "Right", awful.tag.viewnext                              ),
    -- Ctrl Left/Right - swap clients
    awful.key({ modkey, "Control" }, "Left",  function () awful.client.swap.byidx(     -1) end),
    awful.key({ modkey, "Control" }, "Right", function () awful.client.swap.byidx(      1) end),
    -- Ctrl Left/Right - switch screens
    awful.key({ modkey, "Shift"   }, "Left",  function () awful.screen.focus_relative( -1) end),
    awful.key({ modkey, "Shift  " }, "Right", function () awful.screen.focus_relative(  1) end),
    -- u or ²/³ - Go to urgent
    awful.key({ modkey,           }, "u",     awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "#49",   awful.client.urgent.jumpto),
    -- Esc - toggle to previous tag
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),
    -- Ctrl j/k - swap clients
    awful.key({ modkey, "Control" }, "j",     function () awful.client.swap.byidx(     -1) end),
    awful.key({ modkey, "Control" }, "k",     function () awful.client.swap.byidx(      1) end),
    -- j/k or (Shift) Tab - switch clients
    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "Tab",
        function ()
            --awful.client.focus.history.previous()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey, "Shift"   }, "Tab",
        function ()
            --awful.client.focus.history.previous()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),

    -- h/l combo's - master & colomn stuff
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol( 1)         end),
    -- (Shift) Space - switch layouts
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),
    -- r - run command
    awful.key({ modkey,           }, "r",     function () mypromptbox[mouse.screen]:run() end),
    -- Ctrl x - run lua command
    awful.key({ modkey, "Control" }, "x",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey,           }, "x",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey, "Control" }, "n", awful.client.restore),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end),

    --awful.key({ }, "XF86MonBrightnessUp",   ??),
    --awful.key({ }, "XF86MonBrightnessDown", ??),
    --awful.key({ }, "XF86AudioRaiseVolume",  ??),
    --awful.key({ }, "XF86AudioLowerVolume",  ??),
    --awful.key({ }, "XF86AudioMute",         ??),

    --awful.key({ }, "XF86AudioPause",        ??),
    --awful.key({ }, "XF86AudioStop",         ??),
    awful.key({ }, "XF86AudioPrev", function () awful.util.spawn("spotify-control prev")  end),
    awful.key({ }, "XF86AudioPlay", function () awful.util.spawn("spotify-control play")  end),
    awful.key({ }, "XF86AudioNext", function () awful.util.spawn("spotify-control next")  end),

    awful.key({ }, 'XF86AudioLowerVolume', function() awful.util.spawn("pactl set-sink-volume " .. config.pasink .. " -- -5%") end),
    awful.key({ }, 'XF86AudioRaiseVolume', function() awful.util.spawn("pactl set-sink-volume " .. config.pasink .. " -- +5%") end),
    awful.key({ }, "XF86AudioMute", function ()  awful.util.spawn("pactl set-sink-mute " .. config.pasink .. " toggle") end),

    --awful.key({ modkey, }, "o",      function(c) awful.client.movetoscreen(c,c.screen-1) end ),
    -- mod p is stolen by gnome-settings-daemon to trigger xrandr
    --awful.key({ modkey, }, "p",      function(c) awful.client.movetoscreen(c,c.screen+1) end ),
    awful.key({ modkey, }, "=",      function(c) awful.util.spawn_with_shell("/usr/bin/pidgin") end ),
    awful.key({ modkey, "Shift"   }, "o",
        function (c)
            local curidx = awful.tag.getidx(c:tags()[1])
            if curidx == 1 then
                c:tags({screen[mouse.screen]:tags()[9]})
            else
                c:tags({screen[mouse.screen]:tags()[curidx - 1]})
            end
        end),
    awful.key({ modkey, "Shift"   }, "p",
      function (c)
            local curidx = awful.tag.getidx(c:tags()[1])
            if curidx == 9 then
                c:tags({screen[mouse.screen]:tags()[1]})
            else
                c:tags({screen[mouse.screen]:tags()[curidx + 1]})
            end
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    keys.global = awful.util.table.join(keys.global,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))



------------------------------------------------------------------------------
-- Rules ---------------------------------------------------------------------
------------------------------------------------------------------------------
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
		             size_hints_honor = false,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
	     	         floating = true
	                }
      },

    -- Misc apps not floating
   { rule_any   = { instance = { "nautilus", "eog" },
                    class = { "File-roller" } },
     except_any = { type = { "dialog" } },
     properties = { floating = false } },

    -- Browser on tag 1
    { rule_any = { class = { "Google-chrome", "Iceweasel", "Firefox", "Chromium", "Conkeror" } },
      rule = { role = "browser" },
      except_any = { role = { "GtkFileChooserDialog" }, type = { "dialog"} },
      properties = { tag = tags[1][1],
                     focus = true,
	     	         floating = false
	     	       },
       --callback = function(c)
       --   	-- All windows should be slaves, except the browser windows.
       --   	if c.role ~= "browser" then awful.client.setmaster(c) end
       --		end
      },
    { rule_any = { class = { "Google-chrome", "Iceweasel", "Firefox", "Chromium", "Conkeror" } },
      except_any = { role = { "browser", "GtkFileChooserDialog" }, type = { "dialog"}  },
      properties = { focus = true,
	     	         floating = true
	     	       },
       callback = function(c)
          	-- All windows should be slaves, except the browser windows.
          	if c.role ~= "browser" then awful.client.setslave(c) end
       		end
      },
     -- Flash with Firefox
   { rule = { instance = "plugin-container" },
     properties = { floating = true } },
     -- Flash with Chromium
   { rule = { instance = "exe", class = "Exe" },
     properties = { floating = true } },

    -- Terminals
    { rule_any = { class = { "Terminator" } },
      properties = { focus = true,
	     	         floating = false
	     	       }
      },

    -- IM and IRC
    { rule_any = { role = { "irc" } },
      properties = { tag = tags[1][2],
                     focus = true,
	     	         floating = false
	     	       },
      callback = awful.client.setmaster
      },
   { rule = { class = "Pidgin" },
     rule_any = { role = { "conversation", "buddy_list" } },
     properties = { tag = tags[1][2],
		            floating = false
		            },
     callback = function(c) awful.client.setslave(c) end
--     callback = awful.client.setmaster
--     callback = function(c)
--	   	   local w_area = screen[ c.screen ].workarea
--	   	   local strutwidth = 400
--	   	   c:struts( { right = strutwidth } )
--	   	   c:geometry( { x = w_area.width - strutwidth, width = strutwidth, y = w_area.y, height = w_area.height } )
--                end
     },
    { rule_any =   { class = { "Pidgin" } },
      except_any = { role =  { "buddy_list", "conversation" } },
      properties = { tag = tags[1][2],
                     focus = true,
	     	         floating = true
	     	       },
      callback = function (c)
                        awful.placement.centered(c,nil)
                        awful.client.setslave(c)
                        end
      },

    -- Development stuff on tag 5
    { rule_any = { class = { "jetbrains-idea" } },
      except_any = { name = { "Confirm Exit", "Open File or Project" } },
      properties = { tag = tags[1][5],
      		         floating = false
	               }
      },
    -- Pop-up stuff on tag 8
    { rule_any = { class = { "Update-manager", "Update-notifier", "Gnome-control-center" } },
      except_any = { role = { "browser", "GtkFileChooserDialog" } },
      properties = { tag = tags[1][8],
      		         floating = true,
		             sticky = false,
		             minimized = false,
		             urgent = true
	               }
      },

    -- Music players on tag 9
    { rule_any = { class = { "Spotify", "nuvolaplayer", "rhythmbox" } },
      properties = { tag = tags[1][9],
                     focus = true,
	     	         floating = false
	     	     }
      },

    -- Should not be master
    { rule_any = { class = { config.termclass, "Transmission-gtk", "Keepassx", },
                   instance = { "Download" } },
      except = { icon_name = "QuakeConsoleNeedsUniqueName" },
      properties = { },
      callback = awful.client.setslave },

    -- Floating windows
    { rule_any = { class = { "Display.im6", "Key-mon" } },
      properties = { floating = true } },

}

------------------------------------------------------------------------------
-- Signals -------------------------------------------------------------------
------------------------------------------------------------------------------
-- Signal function to execute when a new client appears.
client.add_signal("manage", function (c, startup)
    -- Add a titlebar
    --awful.titlebar.add(c, { modkey = modkey })

    -- Enable sloppy focus
    c:add_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.add_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.add_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)


------------------------------------------------------------------------------
-- Functionality Modules -----------------------------------------------------
------------------------------------------------------------------------------
loadrc("xrandr")
loadrc("xrun")


------------------------------------------------------------------------------
-- Set keys ------------------------------------------------------------------
------------------------------------------------------------------------------
root.keys(keys.global)


------------------------------------------------------------------------------
-- Startup -------------------------------------------------------------------
------------------------------------------------------------------------------

awful.util.spawn_with_shell("/usr/local/bin/awstartapps")

------------------------------------------------------------------------------
