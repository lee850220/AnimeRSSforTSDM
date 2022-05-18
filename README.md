# AnimeRSSforTSDM  
![](https://img.shields.io/badge/tag-v1.3-blue)  ![](https://img.shields.io/badge/maintaince%3F-yes-brightgreen)  [![Linux](https://svgshare.com/i/Zhy.svg)](https://svgshare.com/i/Zhy.svg)  
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
- Auto edit post on TSDM.

# Changelog
## [[v1.3](https://github.com/lee850220/AnimeRSSforTSDM/commit/e22590f6f66debad06566444b9b7f5ed8add7c4a)] - 2022-05-21
### Added
- Apply timezone to push notifications.
- Auto identify episode for post title.
- Auto move files to each series folder on Baidu Netdisk.
- Auto reply on TSDM with rules for specific board.
- Download & Upload time statistic in push notifications.
- Mutex lock for post request. (TSDM has post CD with 10 sec)
- New column for post title and auto reply content in RSSLIST.txt.
- Upload files with [**BaiduPCS-Go**](https://github.com/qjfoidnh/BaiduPCS-Go) (support multi-thread upload with max 100, currently 64)

### Fixed
- Change URL translation function.
- Change format for TSDM post.
- Publish list out of sync on publish sites. (use addition check method)
- Simplify log output.

### Removed
- Disable pyby functions.

## [[v1.0](https://github.com/lee850220/AnimeRSSforTSDM/releases/tag/v1.0)] - 2022-05-16
### Added
- Calculate timezone for check time function.
- Auto generate Baidu share link and push notification to LINE.
- Auto post to TSDM.


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