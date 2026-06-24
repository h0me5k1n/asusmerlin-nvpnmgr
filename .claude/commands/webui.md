# Skill: WebUI Development (vpnmgr_www.*)

## Purpose

This skill covers the vpnmgr Web UI — an ASP page, JavaScript file, and CSS stylesheet that integrate into the AsusWRT-Merlin router's admin interface via the Addons API. The WebUI allows users to configure VPN clients, select providers/countries/servers, set schedules, and monitor connection status without SSH.

Read `CLAUDE.md` first for project-wide context.

## Architecture

### File Roles

| File | Role |
|------|------|
| `vpnmgr_www.asp` | HTML template with embedded ASP directives. Rendered by the router's `httpd`. Defines the page structure, form fields, and injects initial data via `<% %>` tags. |
| `vpnmgr_www.js` | Client-side logic. Loads config from `/ext/vpnmgr/config.htm`, populates form fields, handles provider-specific UI toggling, submits changes back to the script. |
| `vpnmgr_www.css` | Styles. Must match the AsusWRT-Merlin dark theme (dark greys, specific accent colours). |

### How It Integrates With Merlin

1. During install, `vpnmgr.sh` calls `am_settings_set` and copies the ASP/JS/CSS to `/jffs/addons/vpnmgr.d/`
2. The Addons API mounts the page as a tab under the VPN menu in the router WebUI
3. The page loads at a URL like `http://router.asus.com/user/vpnmgr.asp`
4. Data exchange between WebUI and script happens via:
   - **Config read:** JS fetches `/ext/vpnmgr/config.htm` (a plain-text key=value dump)
   - **Config write:** JS POSTs changes which the script picks up and writes to the settings file
   - **Live data:** JS fetches `/tmp/vpnmgrserverloads.tmp` for current server load stats

### Data Flow

```
┌─────────────┐     GET /ext/vpnmgr/config.htm      ┌──────────────────┐
│             │ ──────────────────────────────────►  │                  │
│  Browser    │                                      │  vpnmgr.sh       │
│  (JS/ASP)   │  ◄──────────────────────────────────  │  (generates      │
│             │     key=value config text             │   config.htm)    │
│             │                                      │                  │
│             │     POST settings changes            │                  │
│             │ ──────────────────────────────────►  │  (writes to      │
│             │                                      │   vpnmgr.conf)   │
└─────────────┘                                      └──────────────────┘
```

## ASP Page Conventions

### Merlin Addons API Page Structure

The ASP page follows a strict template expected by Merlin's httpd:

```html
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
<meta HTTP-EQUIV="Expires" CONTENT="-1"/>
<link rel="shortcut icon" href="images/favicon.png"/>
<link rel="icon" href="images/favicon.png"/>
<title>vpnmgr</title>

<!-- Merlin standard includes -->
<link rel="stylesheet" type="text/css" href="index_style.css"/>
<link rel="stylesheet" type="text/css" href="form_style.css"/>
<link rel="stylesheet" type="text/css" href="/ext/shared-jy/shared-jy.css"/>

<!-- vpnmgr custom styles -->
<link rel="stylesheet" type="text/css" href="/ext/vpnmgr/vpnmgr_www.css"/>

<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/shared-jy.js"></script>
<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/vpnmgr/vpnmgr_www.js"></script>
</head>

<body onload="initial();">
<!-- Page content follows Merlin layout conventions -->
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>

<table class="content" align="center" cellpadding="0" cellspacing="0">
  <tr>
    <td width="17">&nbsp;</td>
    <td valign="top" width="202">
      <div id="mainMenu"></div>
      <div id="subMenu"></div>
    </td>
    <td valign="top">
      <div id="tabMenu" class="submenuBlock"></div>
      <!-- Main content area -->
      <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
        <tr>
          <td align="left" valign="top">
            <!-- vpnmgr UI tables go here -->
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
```

### Important Constraints

- **No modern JS frameworks** — vanilla JavaScript with jQuery (already loaded by Merlin)
- **No ES6+ syntax** — older browsers and the router's httpd may not handle it. Use `var`, not `let`/`const`. Use `function(){}`, not arrow functions.
- **No fetch API** — use `jQuery.ajax()` or `XMLHttpRequest`
- **Table-based layout** — Merlin's UI is table-based. Match the existing `.SettingsTable` pattern.
- **Form name:** `document.form` is the standard Merlin form reference

## JavaScript Patterns

### Configuration Loading

```javascript
var $j = jQuery.noConflict();

function get_conf_file() {
    $j.ajax({
        url: "/ext/vpnmgr/config.htm",
        dataType: "text",
        error: function() {
            setTimeout(get_conf_file, 1000);
        },
        success: function(data) {
            var settings = data.split("\n");
            settings = settings.filter(Boolean);
            // Parse key=value pairs
            window.vpnmgr_settings = [];
            for (var i = 0; i < settings.length; i++) {
                if (settings[i].indexOf("#") === -1) {
                    var setting = settings[i].split("=");
                    window.vpnmgr_settings.push(setting);
                }
            }
            // Populate UI from settings
            PopulateUI();
        }
    });
}
```

### Provider-Specific UI Toggling

With the modular provider architecture, the WebUI needs to show/hide fields based on selected provider:

```javascript
function ProviderChanged(vpnNo, provider) {
    // Hide all provider-specific option groups
    $j(".provider-options-" + vpnNo).hide();

    // Show the selected provider's options
    $j("#provider-" + provider + "-options-" + vpnNo).show();

    // Refresh country/city dropdowns for this provider
    RefreshCountryList(vpnNo, provider);
}
```

### Dynamic Country/City Lists

For the modular provider system, country/city lists come from provider sub-scripts and are served via cached data files:

```javascript
function RefreshCountryList(vpnNo, provider) {
    $j.ajax({
        url: "/ext/vpnmgr/countries_" + provider + ".htm",
        dataType: "text",
        success: function(data) {
            var select = $j("[name=vpnmgr_vpn" + vpnNo + "_countryname]");
            select.empty();
            var lines = data.split("\n").filter(Boolean);
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split("|");
                select.append(
                    $j("<option></option>").val(parts[0]).text(parts[1])
                );
            }
        }
    });
}
```

### Settings Save

```javascript
function SaveSettings() {
    // Build the settings string from form values
    var settings = "";
    for (var vpnno = 1; vpnno <= 5; vpnno++) {
        settings += BuildVPNSettings(vpnno);
    }

    // POST back to the script
    $j.ajax({
        url: "/ext/vpnmgr/save.htm",
        type: "POST",
        data: settings,
        success: function() {
            // Show success notification
            ShowNotification("Settings saved successfully");
        },
        error: function() {
            ShowNotification("Error saving settings", "error");
        }
    });
}
```

## CSS Conventions

### Merlin Theme Matching

The router UI uses a dark theme. Key colours:

```css
/* Background layers */
.SettingsTable {
    background-color: #1F2D35;
}

.SettingsTable td.settingname {
    background-color: #1F2D35;
    background: #2F3A3E;
    border-right: solid 1px #000;
    font-weight: bolder;
}

.SettingsTable td.settingvalue {
    text-align: left;
    border-right: solid 1px #000;
}

/* State indicators */
.SettingsTable .invalid {
    background-color: #8b0000;  /* Dark red for errors */
}

.SettingsTable .disabled {
    background-color: #CCC;
    color: #888;
}
```

### Responsive Considerations

The router WebUI is not responsive — it targets desktop browsers at ~1024px+ width. Don't add responsive breakpoints; match the existing fixed-width table layout.

## Adapting the WebUI for Modular Providers

### What Needs to Change

1. **Provider dropdown** — Each VPN client row needs a provider selector that drives which options are shown
2. **Dynamic option groups** — Country lists, VPN types, and protocol options differ by provider. These should populate from the provider's cached data files rather than hardcoded JS arrays
3. **Remove hardcoded provider arrays** — The current JS has `nordvpncountries=[]`, `piacountries=[]`, `wevpncountries=[]`. Replace with dynamic loading per provider
4. **Server load display** — Already works per-provider via `getServerLoad`, just needs to dispatch correctly

### WebUI ↔ Provider Data Files

The core script generates data files that the WebUI reads:

```
/ext/vpnmgr/config.htm              — main settings (all VPN clients)
/ext/vpnmgr/countries_nordvpn.htm   — NordVPN country list (id|name)
/ext/vpnmgr/cities_nordvpn_228.htm  — NordVPN cities for country 228 (id|name)
/ext/vpnmgr/types_nordvpn.htm       — NordVPN VPN types (id|name)
/ext/vpnmgr/providers.htm           — list of installed providers (name|displayname|version)
```

These are generated by the core script calling provider functions and writing the output. The WebUI only reads these files — it never calls provider APIs directly.

## Testing the WebUI

1. **On a real router** — SCP the files to `/jffs/addons/vpnmgr.d/` and reload the page
2. **Browser dev tools** — The router's httpd serves the page; use Chrome/Firefox dev tools to inspect, debug JS, and check network requests
3. **Standalone mockup** — For layout work, you can serve the ASP as plain HTML locally (the `<% %>` tags won't execute but the structure is visible). Mock the config.htm data with a static file.

## Common Pitfalls

- **`$j` not `$`** — Always use `$j` for jQuery (noConflict mode to avoid clashing with Merlin's prototype.js)
- **No template literals** — Use `"string" + variable + "string"` concatenation, not backtick strings
- **`document.form`** — Merlin's standard form reference; don't create your own `<form>` tags
- **Cache busting** — Append `?ts=` + timestamp to AJAX URLs if stale data is a problem
- **The httpd is primitive** — It doesn't support all HTTP methods or headers you'd expect. Stick to GET and POST with simple content types
