# AnimeRSSforTSDM  
![](https://img.shields.io/badge/tag-v0.2-blue)  ![](https://img.shields.io/badge/maintaince%3F-yes-brightgreen)  [![Linux](https://svgshare.com/i/Zhy.svg)](https://svgshare.com/i/Zhy.svg)  
This is a project to automatically transfer Anime to Baidu netdisk with some rules on TSDM.
<br>
<br>
Watch this [**post**](https://www.tsdm39.net/forum.php?mod=viewthread&tid=1101198&fromuid=675439) in detail. 
<br>
<br>

# System Flow Chart
![](https://kdrive.ga/index.php/s/32de8CArz5yet5c/download)

# Ongoing
- Support multiple RSS sites.
- Auto create share links with Baidu API.
- Auto post on TSDM.
- Auto edit post on TSDM.

# Changelog

## [[v0.2](https://github.com/lee850220/AnimeRSSforTSDM/commit/d74ce5285ebf1aa978048a879bed106098e240fb)] - 2022-05-15
### Added
- Able to add comment on each RSS in RSS list file.

### Fixed
- Change RSS source to [**Bangumi**](https://bangumi.moe/), due to bad cache time on DMHY.

### Unsupported
- No longer to support RSS of DMHY.

## [[v0.1](https://github.com/lee850220/AnimeRSSforTSDM/commit/3b8fbde57deb28212d3435d80270029f0b71a45e)] - 2022-05-03
### Added
- Auto read RSS to get torrent. (DMHY)
- Auto submit task to Aria2.
- Auto upload to Baidu with bypy.
- Scheduled with cron.