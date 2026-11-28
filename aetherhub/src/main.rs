use gtk4::gdk::Display;
use gtk4::gio::ApplicationFlags;
use gtk4::prelude::*;
use gtk4::{
    AlertDialog, Align, Application, ApplicationWindow, Box as GtkBox, Button, CssProvider,
    DropDown, Grid, Label, Orientation, PolicyType, ScrolledWindow, Separator, SpinButton, Stack,
    StackSidebar, StackTransitionType, StringObject, STYLE_PROVIDER_PRIORITY_APPLICATION,
};
use std::env;
use std::fs;
use std::process::Command;

const APP_ID: &str = "org.aetheros.AetherHub";
const HELPER: &str = "/usr/local/sbin/aetheros-tune";

fn run_cmd(program: &str, args: &[&str]) -> (bool, String) {
    match Command::new(program).args(args).output() {
        Ok(out) => {
            let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
            let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
            let msg = if !stdout.is_empty() { stdout } else { stderr };
            (out.status.success(), msg)
        }
        Err(e) => (false, e.to_string()),
    }
}

fn run_privileged(args: &[&str]) -> (bool, String) {
    let mut full = Vec::with_capacity(args.len() + 1);
    full.push(HELPER);
    full.extend_from_slice(args);
    run_cmd("sudo", &full)
}

fn read_trimmed(path: &str) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

fn os_pretty_name() -> String {
    if let Some(content) = read_trimmed("/etc/os-release") {
        for line in content.lines() {
            if let Some(val) = line.strip_prefix("PRETTY_NAME=") {
                return val.trim_matches('"').to_string();
            }
        }
    }
    "AetherOS".to_string()
}

fn kernel_release() -> String {
    run_cmd("uname", &["-r"]).1
}

fn arch_name() -> String {
    run_cmd("uname", &["-m"]).1
}

fn cpu_summary() -> String {
    let info = read_trimmed("/proc/cpuinfo").unwrap_or_default();
    let model = info
        .lines()
        .find_map(|l| l.strip_prefix("model name"))
        .and_then(|l| l.split_once(':'))
        .map(|(_, v)| v.trim().to_string())
        .unwrap_or_else(|| "Unknown CPU".to_string());
    let cores = info.lines().filter(|l| l.starts_with("processor\t:")).count();
    if cores > 0 {
        format!("{model} ({cores} threads)")
    } else {
        model
    }
}

fn mem_summary() -> String {
    let info = read_trimmed("/proc/meminfo").unwrap_or_default();
    let mut total_kb = 0u64;
    let mut avail_kb = 0u64;
    for line in info.lines() {
        if let Some(rest) = line.strip_prefix("MemTotal:") {
            total_kb = rest
                .split_whitespace()
                .next()
                .and_then(|n| n.parse().ok())
                .unwrap_or(0);
        } else if let Some(rest) = line.strip_prefix("MemAvailable:") {
            avail_kb = rest
                .split_whitespace()
                .next()
                .and_then(|n| n.parse().ok())
                .unwrap_or(0);
        }
    }
    if total_kb > 0 {
        let total_gb = total_kb as f64 / 1024.0 / 1024.0;
        let used_gb = (total_kb.saturating_sub(avail_kb)) as f64 / 1024.0 / 1024.0;
        format!("{used_gb:.1} GiB / {total_gb:.1} GiB used")
    } else {
        "Unknown".to_string()
    }
}

fn uptime_summary() -> String {
    if let Some(raw) = read_trimmed("/proc/uptime") {
        if let Some(secs) = raw.split_whitespace().next().and_then(|s| s.parse::<f64>().ok()) {
            let total = secs as u64;
            let hrs = total / 3600;
            let mins = (total % 3600) / 60;
            return format!("{hrs}h {mins}m");
        }
    }
    "Unknown".to_string()
}

fn root_disk_summary() -> String {
    let (ok, out) = run_cmd("df", &["-h", "--output=used,size,pcent", "/"]);
    if ok {
        if let Some(line) = out.lines().nth(1) {
            let cols: Vec<&str> = line.split_whitespace().collect();
            if cols.len() >= 3 {
                return format!("{} / {} ({})", cols[0], cols[1], cols[2]);
            }
        }
    }
    "Unknown".to_string()
}

fn desktop_env() -> String {
    env::var("XDG_CURRENT_DESKTOP")
        .or_else(|_| env::var("DESKTOP_SESSION"))
        .unwrap_or_else(|_| "Unknown".to_string())
}

fn current_governor() -> String {
    read_trimmed("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
        .unwrap_or_else(|| "schedutil".to_string())
}

fn available_governors() -> Vec<String> {
    if let Some(raw) = read_trimmed("/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors") {
        let list: Vec<String> = raw.split_whitespace().map(|s| s.to_string()).collect();
        if !list.is_empty() {
            return list;
        }
    }
    vec![
        "powersave".into(),
        "schedutil".into(),
        "performance".into(),
        "ondemand".into(),
        "conservative".into(),
    ]
}

fn current_swappiness() -> f64 {
    read_trimmed("/proc/sys/vm/swappiness")
        .and_then(|s| s.parse::<f64>().ok())
        .unwrap_or(60.0)
}

fn service_state(unit: &str) -> String {
    let (_, out) = run_cmd("systemctl", &["is-active", &format!("{unit}.service")]);
    if out.is_empty() {
        "unknown".to_string()
    } else {
        out
    }
}

fn styled_label(text: &str, css_class: Option<&str>) -> Label {
    let l = Label::new(Some(text));
    l.set_xalign(0.0);
    if let Some(cls) = css_class {
        l.add_css_class(cls);
    }
    l
}

fn make_card() -> GtkBox {
    let b = GtkBox::new(Orientation::Vertical, 8);
    b.add_css_class("card");
    b
}

fn card_with(child: &impl IsA<gtk4::Widget>) -> GtkBox {
    let b = make_card();
    b.append(child);
    b
}

fn info_card(title: &str, description: &str) -> GtkBox {
    let b = make_card();
    b.append(&styled_label(title, Some("field-value")));
    let d = styled_label(description, Some("secondary"));
    d.set_wrap(true);
    b.append(&d);
    b
}

fn show_alert(win: &ApplicationWindow, message: &str) {
    let text = if message.is_empty() { "Done" } else { message };
    AlertDialog::builder().message(text).build().show(Some(win));
}

fn add_page(stack: &Stack, name: &str, icon: &str, title: &str) -> GtkBox {
    let page = GtkBox::new(Orientation::Vertical, 16);
    page.set_margin_top(22);
    page.set_margin_bottom(24);
    page.set_margin_start(28);
    page.set_margin_end(28);
    let heading = styled_label(title, Some("section-title"));
    page.append(&heading);
    stack.add_titled(&page, Some(&name.to_lowercase()), &format!("{icon}  {name}"));
    page
}

fn install_css() {
    let css = CssProvider::new();
    css.load_from_data(
        "
        .window-bg { background: #11151d; color: #e8ebf2; }
        .brand-symbol { color: #f17850; font-size: 36px; }
        .brand-name { font-size: 19px; font-weight: 700; color: #f3f4f7; }
        .eyebrow { color: #929bab; font-size: 9px; letter-spacing: 1.6px; }
        .page-title { font-size: 22px; font-weight: 700; color: #f3f4f7; }
        .section-title { font-size: 18px; font-weight: 600; color: #f3f4f7; }
        .card { background: #1c2330; border: 1px solid #2b3444; border-radius: 10px; padding: 16px; }
        .field-label { color: #aab3c2; font-size: 12px; }
        .field-value { color: #f1f3f7; font-size: 14px; font-weight: 600; }
        .secondary { color: #98a2b3; font-size: 12px; }
        .mono { font-family: monospace; font-size: 12px; color: #d5dce8; }
        button { border-radius: 7px; padding: 7px 12px; }
        button.suggested-action { background: #e96f4b; color: white; }
        stacksidebar row:selected { background: #2b3545; border-radius: 7px; }
        ",
    );
    if let Some(display) = Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &css,
            STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

fn build_ui(app: &Application) {
    let win = ApplicationWindow::builder()
        .application(app)
        .title("AetherHub")
        .default_width(960)
        .default_height(680)
        .build();

    let shell = GtkBox::new(Orientation::Horizontal, 0);
    shell.add_css_class("window-bg");

    // Sidebar
    let sidebar = GtkBox::new(Orientation::Vertical, 12);
    sidebar.set_size_request(224, -1);
    sidebar.set_margin_top(22);
    sidebar.set_margin_bottom(20);
    sidebar.set_margin_start(18);
    sidebar.set_margin_end(14);

    let brand = GtkBox::new(Orientation::Horizontal, 10);
    let symbol = styled_label("Ⓐ", Some("brand-symbol"));
    let brand_text = GtkBox::new(Orientation::Vertical, 1);
    brand_text.append(&styled_label("AetherHub", Some("brand-name")));
    brand_text.append(&styled_label("SYSTEM SETTINGS", Some("eyebrow")));
    brand.append(&symbol);
    brand.append(&brand_text);
    sidebar.append(&brand);
    sidebar.append(&Separator::new(Orientation::Horizontal));

    let stack = Stack::new();
    stack.set_transition_type(StackTransitionType::Crossfade);
    stack.set_transition_duration(150);
    stack.set_hexpand(true);
    stack.set_vexpand(true);

    let nav = StackSidebar::new();
    nav.set_stack(&stack);
    nav.set_vexpand(true);
    sidebar.append(&nav);
    shell.append(&sidebar);
    shell.append(&Separator::new(Orientation::Vertical));

    // Main panel
    let main = GtkBox::new(Orientation::Vertical, 0);
    main.set_hexpand(true);

    let top = GtkBox::new(Orientation::Horizontal, 8);
    top.set_margin_top(22);
    top.set_margin_bottom(16);
    top.set_margin_start(28);
    top.set_margin_end(28);
    let page_title = styled_label("Overview", Some("page-title"));
    top.append(&page_title);
    main.append(&top);
    main.append(&Separator::new(Orientation::Horizontal));

    let scroller = ScrolledWindow::new();
    scroller.set_policy(PolicyType::Never, PolicyType::Automatic);
    scroller.set_vexpand(true);
    scroller.set_child(Some(&stack));
    main.append(&scroller);
    shell.append(&main);

    // 1. Overview
    let overview = add_page(&stack, "Overview", "⌂", "Your system at a glance");
    let os_name = os_pretty_name();
    let kernel = kernel_release();
    let arch = arch_name();
    let cpu = cpu_summary();
    let mem = mem_summary();
    let disk = root_disk_summary();
    let uptime = uptime_summary();
    let de = desktop_env();

    let details = [
        ("Operating system", os_name.as_str()),
        ("Desktop session", de.as_str()),
        ("Kernel", kernel.as_str()),
        ("Architecture", arch.as_str()),
        ("CPU", cpu.as_str()),
        ("Memory", mem.as_str()),
        ("Root disk (/)", disk.as_str()),
        ("Uptime", uptime.as_str()),
    ];
    let grid = Grid::new();
    grid.set_column_spacing(12);
    grid.set_row_spacing(12);
    grid.set_column_homogeneous(true);
    for (i, (k, v)) in details.iter().enumerate() {
        let card = make_card();
        card.append(&styled_label(k, Some("field-label")));
        let val = styled_label(v, Some("field-value"));
        val.set_wrap(true);
        card.append(&val);
        grid.attach(&card, (i % 2) as i32, (i / 2) as i32, 1, 1);
    }
    overview.append(&grid);

    let summary_text = format!(
        "OS: {os_name}\nDesktop: {de}\nKernel: {kernel} ({arch})\nCPU: {cpu}\nMemory: {mem}\nDisk (/): {disk}\nUptime: {uptime}"
    );
    let copy_btn = Button::with_label("Copy System Summary");
    copy_btn.set_halign(Align::Start);
    copy_btn.add_css_class("suggested-action");
    {
        let win_c = win.clone();
        let summary_c = summary_text.clone();
        copy_btn.connect_clicked(move |_| {
            if let Some(display) = Display::default() {
                display.clipboard().set_text(&summary_c);
                show_alert(&win_c, "System summary copied to clipboard.");
            }
        });
    }
    overview.append(&copy_btn);

    // 2. Performance
    let perf = add_page(&stack, "Performance", "◈", "Performance & Memory");
    perf.append(&info_card(
        "CPU frequency scaling",
        "Choose a governor supported by your CPU driver. Applies immediately.",
    ));

    let gov_row = GtkBox::new(Orientation::Horizontal, 10);
    gov_row.append(&styled_label("CPU governor", Some("field-label")));
    let govs = available_governors();
    let gov_refs: Vec<&str> = govs.iter().map(|s| s.as_str()).collect();
    let gov_dd = DropDown::from_strings(&gov_refs);
    let cur_gov = current_governor();
    if let Some(pos) = govs.iter().position(|g| g == &cur_gov) {
        gov_dd.set_selected(pos as u32);
    }
    gov_row.append(&gov_dd);
    let gov_apply = Button::with_label("Apply");
    gov_apply.add_css_class("suggested-action");
    {
        let win_c = win.clone();
        let gov_dd_c = gov_dd.clone();
        gov_apply.connect_clicked(move |_| {
            if let Some(item) = gov_dd_c
                .selected_item()
                .and_then(|o| o.downcast::<StringObject>().ok())
            {
                let val = item.string().to_string();
                let (ok, msg) = run_privileged(&["governor", &val]);
                show_alert(
                    &win_c,
                    if msg.is_empty() {
                        if ok { "Governor updated." } else { "Failed to set governor." }
                    } else {
                        &msg
                    },
                );
            }
        });
    }
    gov_row.append(&gov_apply);
    perf.append(&card_with(&gov_row));

    let swap_row = GtkBox::new(Orientation::Horizontal, 12);
    swap_row.append(&styled_label("VM swappiness", Some("field-label")));
    let sw_spin = SpinButton::with_range(0.0, 100.0, 1.0);
    sw_spin.set_value(current_swappiness());
    swap_row.append(&sw_spin);
    let sw_apply = Button::with_label("Apply");
    {
        let win_c = win.clone();
        let sw_c = sw_spin.clone();
        sw_apply.connect_clicked(move |_| {
            let val = sw_c.value_as_int().to_string();
            let (ok, msg) = run_privileged(&["swappiness", &val]);
            show_alert(
                &win_c,
                if msg.is_empty() {
                    if ok { "Swappiness updated." } else { "Failed to update swappiness." }
                } else {
                    &msg
                },
            );
        });
    }
    swap_row.append(&sw_apply);
    perf.append(&card_with(&swap_row));

    let zram_row = GtkBox::new(Orientation::Horizontal, 10);
    zram_row.append(&styled_label("ZRAM swap", Some("field-label")));
    for (label, arg) in [("Enable", "enable"), ("Disable", "disable"), ("Status", "status")] {
        let b = Button::with_label(label);
        let win_c = win.clone();
        b.connect_clicked(move |_| {
            let (ok, msg) = run_privileged(&["zram", arg]);
            show_alert(
                &win_c,
                if msg.is_empty() {
                    if ok { "ZRAM updated." } else { "ZRAM operation failed." }
                } else {
                    &msg
                },
            );
        });
        zram_row.append(&b);
    }
    perf.append(&card_with(&zram_row));

    let cache_row = GtkBox::new(Orientation::Horizontal, 10);
    cache_row.append(&styled_label("Memory & SSD", Some("field-label")));
    let drop_btn = Button::with_label("Drop Page Caches");
    {
        let win_c = win.clone();
        drop_btn.connect_clicked(move |_| {
            let (_, msg) = run_privileged(&["drop-caches"]);
            show_alert(&win_c, &msg);
        });
    }
    let trim_btn = Button::with_label("Run SSD TRIM");
    {
        let win_c = win.clone();
        trim_btn.connect_clicked(move |_| {
            let (_, msg) = run_privileged(&["fstrim"]);
            show_alert(&win_c, &msg);
        });
    }
    cache_row.append(&drop_btn);
    cache_row.append(&trim_btn);
    perf.append(&card_with(&cache_row));

    // 3. Services
    let services = add_page(&stack, "Services", "⚙", "Background Services");
    services.append(&info_card(
        "Service controls",
        "Manage system services with live state detection via systemd.",
    ));
    for (unit, desc) in [
        ("NetworkManager", "Network connection manager"),
        ("bluetooth", "Bluetooth device support"),
        ("cups", "Printing service"),
        ("ssh", "OpenSSH remote access server"),
        ("thermald", "Intel thermal management"),
    ] {
        let row = GtkBox::new(Orientation::Horizontal, 10);
        let texts = GtkBox::new(Orientation::Vertical, 2);
        texts.set_hexpand(true);
        let state = service_state(unit);
        let title = styled_label(&format!("{unit}  [{state}]"), Some("field-value"));
        texts.append(&title);
        texts.append(&styled_label(desc, Some("secondary")));
        row.append(&texts);

        for (label, act) in [
            ("Start", "start"),
            ("Stop", "stop"),
            ("Enable", "enable"),
            ("Disable", "disable"),
        ] {
            let b = Button::with_label(label);
            let win_c = win.clone();
            let title_c = title.clone();
            let unit_s = unit.to_string();
            let act_s = act.to_string();
            b.connect_clicked(move |_| {
                let (ok, msg) = run_privileged(&["service", &unit_s, &act_s]);
                let new_state = service_state(&unit_s);
                title_c.set_text(&format!("{unit_s}  [{new_state}]"));
                show_alert(
                    &win_c,
                    if msg.is_empty() {
                        if ok { "Service updated." } else { "Service command failed." }
                    } else {
                        &msg
                    },
                );
            });
            row.append(&b);
        }
        services.append(&card_with(&row));
    }

    // 4. Network & Diagnostics
    let net = add_page(&stack, "Network", "⇄", "Network & Diagnostics");
    let (_, ip_out) = run_cmd("ip", &["-brief", "addr"]);
    let dns_out = read_trimmed("/etc/resolv.conf").unwrap_or_else(|| "Unavailable".into());
    let net_card = make_card();
    net_card.append(&styled_label("Active interfaces", Some("field-label")));
    let ip_lbl = styled_label(
        if ip_out.is_empty() { "No interface info" } else { &ip_out },
        Some("mono"),
    );
    ip_lbl.set_wrap(true);
    net_card.append(&ip_lbl);
    net.append(&net_card);

    let dns_card = make_card();
    dns_card.append(&styled_label("DNS configuration (/etc/resolv.conf)", Some("field-label")));
    let dns_lbl = styled_label(&dns_out, Some("mono"));
    dns_lbl.set_wrap(true);
    dns_card.append(&dns_lbl);
    net.append(&dns_card);

    let net_actions = GtkBox::new(Orientation::Horizontal, 10);
    let ping_btn = Button::with_label("Test Internet (1.1.1.1)");
    ping_btn.add_css_class("suggested-action");
    {
        let win_c = win.clone();
        ping_btn.connect_clicked(move |_| {
            let (ok, msg) = run_cmd("ping", &["-c", "2", "-W", "2", "1.1.1.1"]);
            show_alert(
                &win_c,
                if ok { &msg } else { "No connectivity to 1.1.1.1" },
            );
        });
    }
    let nm_restart = Button::with_label("Restart NetworkManager");
    {
        let win_c = win.clone();
        nm_restart.connect_clicked(move |_| {
            let (ok, msg) = run_privileged(&["service", "NetworkManager", "restart"]);
            show_alert(
                &win_c,
                if msg.is_empty() {
                    if ok { "NetworkManager restarted." } else { "Restart failed." }
                } else {
                    &msg
                },
            );
        });
    }
    net_actions.append(&ping_btn);
    net_actions.append(&nm_restart);
    net.append(&card_with(&net_actions));

    // 5. Appearance
    let appearance = add_page(&stack, "Appearance", "◐", "Appearance");
    appearance.append(&info_card(
        "AetherOS wallpapers",
        "Apply a built-in AetherOS wallpaper to your XFCE, GNOME, or KDE session.",
    ));
    let wp_row = GtkBox::new(Orientation::Horizontal, 10);
    for (label, path) in [
        (
            "Mountain dusk",
            "/usr/share/aetheros/branding/aetheros-wallpaper-mountain.svg",
        ),
        (
            "Graphite abstract",
            "/usr/share/aetheros/branding/aetheros-wallpaper-abstract.svg",
        ),
    ] {
        let b = Button::with_label(label);
        let win_c = win.clone();
        b.connect_clicked(move |_| {
            let (ok, msg) = run_cmd("/usr/local/bin/aetheros-wallpaper", &[path]);
            show_alert(
                &win_c,
                if msg.is_empty() {
                    if ok { "Wallpaper applied." } else { "Failed to apply wallpaper." }
                } else {
                    &msg
                },
            );
        });
        wp_row.append(&b);
    }
    appearance.append(&card_with(&wp_row));

    // 6. Maintenance
    let maint = add_page(&stack, "Maintenance", "⚒", "System Maintenance");
    maint.append(&info_card(
        "System health & cleanup",
        "Check failed systemd units or clean up APT package caches.",
    ));
    let maint_row = GtkBox::new(Orientation::Horizontal, 10);
    let failed_btn = Button::with_label("Check Failed Units");
    {
        let win_c = win.clone();
        failed_btn.connect_clicked(move |_| {
            let (_, msg) = run_cmd("systemctl", &["--failed", "--no-pager"]);
            show_alert(&win_c, &msg);
        });
    }
    let apt_clean_btn = Button::with_label("Clean APT Cache");
    {
        let win_c = win.clone();
        apt_clean_btn.connect_clicked(move |_| {
            let (_, msg) = run_privileged(&["apt-clean"]);
            show_alert(&win_c, &msg);
        });
    }
    maint_row.append(&failed_btn);
    maint_row.append(&apt_clean_btn);
    maint.append(&card_with(&maint_row));

    // 7. About
    let about = add_page(&stack, "About", "ⓘ", "About AetherHub");
    about.append(&info_card(
        "AetherHub 0.4 (Rust + GTK4)",
        "Native compiled GTK4 control center for AetherOS. Privileged changes are routed through the allow-listed /usr/local/sbin/aetheros-tune helper.",
    ));
    about.append(&info_card(
        "AetherOS",
        "PURE. FAST. REFINED.  ·  Debian-based desktop distribution.",
    ));

    stack.connect_visible_child_name_notify(move |s| {
        let title = match s.visible_child_name().as_deref() {
            Some("overview") => "Overview",
            Some("performance") => "Performance",
            Some("services") => "Services",
            Some("network") => "Network",
            Some("appearance") => "Appearance",
            Some("maintenance") => "Maintenance",
            Some("about") => "About",
            _ => "Settings",
        };
        page_title.set_text(title);
    });

    win.set_child(Some(&shell));
    install_css();
    win.present();
}

fn main() {
    let app = Application::builder()
        .application_id(APP_ID)
        .flags(ApplicationFlags::DEFAULT_FLAGS)
        .build();
    app.connect_activate(build_ui);
    app.run();
}
