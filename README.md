# shokz-sync

Auto-download music from SoundCloud, YouTube, Mixcloud, and podcast RSS feeds, then sync to your Shokz OpenSwim Pro headphones when you plug them in.

```
                     ┌─────────────┐
                     │  SoundCloud  │──┐
                     └─────────────┘  │
                     ┌─────────────┐  │    ┌──────────────┐    ┌──────────────────┐
                     │   YouTube    │──┼───>│ ~/Music/     │───>│ Shokz OpenSwim   │
                     └─────────────┘  │    │ ShokzLibrary │    │ Pro (USB)        │
                     ┌─────────────┐  │    └──────────────┘    └──────────────────┘
                     │   Mixcloud   │──┤     download             sync on plug-in
                     └─────────────┘  │     (every 6h)
                     ┌─────────────┐  │
                     │  Podcasts    │──┘
                     └─────────────┘
```

## How It Works

1. **Download** - A systemd timer runs every 6 hours, pulling new tracks from your configured sources into `~/Music/ShokzLibrary/`
2. **Sync** - When you plug in your OpenSwim Pro, a udev rule triggers an automatic sync that copies the newest tracks to the device
3. **Rotate** - Only the newest tracks are kept on the device (default: 20). Old tracks are removed to make room

## Supported Sources

| Type | Example | Notes |
|------|---------|-------|
| SoundCloud | Likes, playlists, artist pages | Uses yt-dlp with browser cookies |
| YouTube | Playlists, channels | Uses yt-dlp with browser cookies |
| Mixcloud | Favorites, user pages | Uses yt-dlp with browser cookies |
| Podcasts | Any RSS feed | Direct download, auto-converts to MP3 |

## Requirements

- **Linux** with systemd (tested on Fedora)
- **yt-dlp** - for SoundCloud/YouTube/Mixcloud downloads
- **ffmpeg** - for audio conversion
- **python3** - for RSS feed parsing
- **curl** - for podcast downloads

Optional:
- **libnotify** (`notify-send`) - for desktop notifications on sync

## Install

```bash
git clone https://github.com/garrickgan/shokz-sync.git
cd shokz-sync
./install.sh
```

The installer will:
- Check and help install dependencies
- Auto-detect your connected Shokz device
- Ask which browser to use for cookie extraction
- Generate your config at `~/.config/shokz-sync/config`
- Install the script to `~/.local/bin/`
- Set up systemd timer for periodic downloads
- Install a udev rule for auto-sync on plug-in (optional, needs sudo)

## Usage

```bash
# Add music sources
shokz-sync add soundcloud 'https://soundcloud.com/user/likes' 'My Likes'
shokz-sync add youtube 'https://www.youtube.com/playlist?list=PLxxx' 'Chill Mix'
shokz-sync add podcast 'https://feeds.example.com/rss' 'My Podcast'

# Import podcasts from an OPML file
shokz-sync import-opml ~/podcasts.opml

# Download new tracks now
shokz-sync download

# Sync to device (must be plugged in)
shokz-sync sync

# Download + sync in one step
shokz-sync auto

# Check status
shokz-sync status

# List configured sources
shokz-sync sources
```

## Adding Sources

Edit `~/.config/shokz-sync/sources.conf` directly, or use the CLI:

```bash
shokz-sync add <type> <url> <label>
```

Format: `type|url|label` (one per line). Comment lines with `#` to disable.

```conf
soundcloud|https://soundcloud.com/user/likes|SoundCloud Likes
youtube|https://www.youtube.com/playlist?list=PLxxx|Chill Playlist
mixcloud|https://www.mixcloud.com/user/favorites/|Mixcloud Favs
podcast|https://feeds.example.com/feed.xml|Weekly Mix Show
```

## Configuration

Config file: `~/.config/shokz-sync/config`

| Setting | Default | Description |
|---------|---------|-------------|
| `DEVICE_LABEL` | `SWIM PRO` | USB mount label of your Shokz device |
| `BROWSER` | `chrome` | Browser for yt-dlp cookie extraction |
| `MAX_DEVICE_TRACKS` | `20` | Max number of tracks to keep on device |
| `MAX_NEW_PER_SYNC` | `0` (unlimited) | Max new tracks to add per sync (0 = no limit) |
| `MAX_DOWNLOADS_PER_SOURCE` | `10` | Max downloads per source per run |
| `RESERVE_MB` | `200` | Reserved free space on device (MB) |

## File Locations

| Path | Purpose |
|------|---------|
| `~/.local/bin/shokz-sync` | Main script |
| `~/.config/shokz-sync/config` | Configuration |
| `~/.config/shokz-sync/sources.conf` | Music sources |
| `~/Music/ShokzLibrary/` | Downloaded tracks |
| `~/.local/share/shokz-sync/sync.log` | Log file |

## Troubleshooting

**Device not detected on plug-in:**
- Check the label: `ls /run/media/$USER/`
- Update `DEVICE_LABEL` in `~/.config/shokz-sync/config`
- Check udev rule: `cat /etc/udev/rules.d/99-shokz-sync.rules`
- Check service logs: `journalctl --user -u shokz-sync.service`

**yt-dlp authentication errors:**
- Make sure you're logged in to SoundCloud/YouTube in your configured browser
- Try a different browser: edit `BROWSER` in config

**Downloads not running automatically:**
- Check timer: `systemctl --user status shokz-sync-download.timer`
- Run manually: `shokz-sync download`

**No space on device:**
- Reduce `MAX_DEVICE_TRACKS` in config
- The sync automatically removes oldest tracks to make room

## Uninstall

```bash
./uninstall.sh
```

Removes the script, systemd units, and udev rule. Optionally removes config and downloaded music.

## License

MIT
