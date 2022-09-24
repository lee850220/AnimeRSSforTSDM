#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <wchar.h>
#include <time.h>

#define BUF_SIZE            1024
#define SLEEP_TIME          1000
#define UP                  "\33[A"
#define ERASE_LINE          "\33[2K\r"
#define COLOR_RESET         "\033[0m"
#define COLOR_RED           "\033[1;31m"
#define COLOR_GREEN         "\033[1;32m"
#define COLOR_YELLOW        "\033[1;33m"
#define COLOR_PURPLE        "\033[1;35m"
#define COLOR_LIGHTBLUE     "\033[1;36m"

#define HTTPCODE_OK         200
#define TIMEZONE            8           // UTC+8

#define LINE_API            "https://notify-api.line.me/api/notify"
#define SERVER_URL          "https://kcloud.one:6800/jsonrpc"

#define JSONRPC             "2.0"
#define METHOD              "aria2.addUri"
#define ID                  "root"

#define CERT_PATH           "/etc/aria2/intermediate.pem"
#define DLDIR               "/kcloud/Aria2/"
#define ARIA2_CONFIG        "/etc/aria2/aria2.conf"
#define POST_FILE           "/etc/aria2/post.txt"
#define TIMESTAMP_FILE      "/etc/aria2/checkpoint"
#define FILENAME_CTIME      "/etc/aria2/convertime.sh"
#define FILENAME_LIST       "/etc/aria2/RSSLIST.txt"
#define FILENAME_RSSTIME    "/etc/aria2/RSSLIST_timestamp"
#define FILENAME_GETFNAME   "/etc/aria2/getfilename.sh"
#define FILENAME_URLENC     "/etc/aria2/URLdecode.py"
#define FILENAME_PXML       "/etc/aria2/prettyXML.py"

#define CMD_CPTS            "cp -f "FILENAME_RSSTIME"_tmp "FILENAME_RSSTIME
#define CMD_RMTS            "rm -f "FILENAME_RSSTIME"_tmp "

#define POST_DELIMIT        "$$$$$"
#define ITEM_HEAD           "<item>"
#define ITEM_END            "</item>"
#define BANGUMI             "bangumi.moe"
#define NYAA                "nyaa.si"

#define MSG_SUCCESS         COLOR_GREEN"Success"COLOR_RESET
#define MSG_FAIL            COLOR_RED"Fail"COLOR_RESET
#define MSG_FAIL_N          "Fail"
#define MSG_ERROR           COLOR_RED"[ERROR]: "COLOR_RESET
#define MSG_ERROR_N         "[ERROR]: "
#define MSG_NOTICE          COLOR_LIGHTBLUE"[Notice]:        "COLOR_RESET
#define MSG_RSS             COLOR_YELLOW"[RSS PATH]:      "COLOR_RESET
#define MSG_TITLE           COLOR_PURPLE"[Title]:         "COLOR_RESET
#define MSG_PUBDATE         COLOR_PURPLE"[PubDate]:       "COLOR_RESET
#define MSG_TORRENT         COLOR_PURPLE"[Torrent Link]:  "COLOR_RESET
#define MSG_CURTIME         "[Current Time]:  "
#define MSG_LASTIME         "[Check Time]:    "
#define MSG_LINE            "{PUSH to LINE}="
#define MSG_ADDTASK         "{Add torrent to Aria2}="
#define MSG_PUSH            ", pushing to LINE...\n"
#define LINE                "---------------------------------------------"
#define DLINE               "============================================="

enum mode {
    MODE_BANGUMI = 1,
    MODE_NYAA
};

struct entry {

    char *str;
    int n;

};

struct entry MONTH[] = {

    "Jan", 0,
    "Feb", 1,
    "Mar", 2,
    "Apr", 3,
    "May", 4,
    "Jun", 5,
    "Jul", 6,
    "Aug", 7,
    "Sep", 8,
    "Oct", 9,
    "Nov", 10,
    "Dec", 11,
    0, -1

};

typedef struct publish {

    char    title      [BUF_SIZE];
    char    ptitle     [BUF_SIZE];
    int     order;
    char    link       [BUF_SIZE];
    char    torrent    [BUF_SIZE];
    char    filename   [BUF_SIZE];
    time_t  pubTime;
    time_t  lastPub;

} publish, * publish_ptr;

typedef struct tm TIME, * TIME_ptr;

bool        is_NOUP;
bool        is_NOP;
int         RSS_CNT         = 0;
int         RSS_PUB_CNT     = 0;
int         TASK_CNT        = 0;
int         MODE;
char        URL_RSS         [BUF_SIZE];
char        LINE_TOKEN      [BUF_SIZE];
char        ARIA2_TOKEN     [BUF_SIZE];
time_t      CUR_TIME;
time_t      LAST_TIME;
time_t      DL_START;
publish     PUBLISH;

const int   len_rss         = strlen("python3 -u  \"\" 2> /dev/null") + 1;
const int   len_torrent     = strlen("wget -qO- '' | grep 會員專用連接") + 1;
const int   len_torrentname = strlen("python3 -u $(./getfilename.sh ) | sed 's/.*\"\\(.*\\)\".$/\\1/'") + 1;
const int   len_filename    = strlen("transmission-show  | grep Name | head -1") + 1;
const int   len_filename_c  = strlen("transmission-show \"\" &> /dev/null;echo $?") + 1;
const int   len_createfile  = strlen("rm -f '.upload'sudo -u apache touch '.upload'") + 1;
const int   len_notify      = strlen("curl -m 15 -sX POST ''" \
                                        " --header 'Content-Type: application/x-www-form-urlencoded'" \
                                        " --header 'Authorization: Bearer '" \
                                        " --data-urlencode 'Message=' ; echo $?") + 1;
const int   len_req         = strlen("curl -m 15 -X POST ''" \
                                          "-w \" Status: %{http_code}\"" \
                                          "-d '{\"jsonrpc\": \"\"," \
                                               "\"method\": \"\"," \
                                               "\"id\": \"\"," \
                                               "\"params\": [\"token:\"," \
                                                           "[\"\"]]}'" \
                                         "--cacert ") + 1;

void    readToken           (void);
void    getRSS              (void);
void    getXML              (const char * const);
void    rm_newline          (char *);
void    create_item         (FILE *);
void    gettorrent          (void);
void    addDownload         (void);
void    show_lasttime       (void);
void    update_checkpoint   (void);
void    task_notify         (void);
void    push_notify         (const char const *);
int     check_source        (const char const *);
time_t  translate_time      (const char const *);
void    convert_time        (char *, time_t);
int     number_for_key      (char *);
void    rmspace             (char *);
void    printline           (void);
void    printdline          (void);
void    cleanenv            (void);


int main(int argc, char *argv[]) {

    char buf[BUF_SIZE];
    time_t terminated;

    // print time info
    time(&CUR_TIME);
    printf(MSG_CURTIME"%s", asctime(localtime(&CUR_TIME)));
    show_lasttime();
    printdline();

    // get tokens
    readToken();

    // read RSS list
    getRSS();
    
    // update checkpoint
    update_checkpoint();
    time(&terminated);
    convert_time(buf, terminated - CUR_TIME);
    printf("Checked %d RSS, and %d has new. Task %d created. Time Elapsed: %s\n", RSS_CNT, RSS_PUB_CNT, TASK_CNT, buf);
    printdline();
    system(CMD_CPTS);
    system(CMD_RMTS);
    return 0;

}

/*
 *  Read LINE & Aria2 Token.
 *  Input:  none
 *  Output: none
 */   
void readToken(void) {

    FILE * fp_config;
    char buf[BUF_SIZE];
    char * start;
    bool is_Aria2 = false, is_LINE = false;

    // read Aria2 config
    fp_config = fopen(ARIA2_CONFIG, "r");
    if (fp_config == NULL) {printf(MSG_ERROR"Cannot open aria2 config.\n"); cleanenv();}
    while (fgets(buf, sizeof(buf), fp_config) != NULL) {

        rm_newline(buf);
        // find Aria2 token
        start = strstr(buf, "rpc-secret=");
        if (start) {
            
            start += strlen("rpc-secret=");
            memset(ARIA2_TOKEN, 0, sizeof(ARIA2_TOKEN));
            strcpy(ARIA2_TOKEN, start);
            is_Aria2 = true;

        }
        
        // find LINE token
        start = strstr(buf, "LINE=");
        if (start) {
            
            start += strlen("LINE=");
            memset(LINE_TOKEN, 0, sizeof(LINE_TOKEN));
            strcpy(LINE_TOKEN, start);
            is_LINE = true;

        }
        if (is_Aria2 && is_LINE) break;

    }
    fclose(fp_config);

}

/*
 *  Process each line in RSS list.
 *  Input:  none
 *  Output: none
 */   
void getRSS(void) {

    char * ptr, * pptr, * ppptr;
    char buf[BUF_SIZE];
    FILE * fp_list, * fp_tlist, * fp_ttlist;

    fp_list = fopen(FILENAME_LIST, "r");
    fp_tlist = fopen(FILENAME_RSSTIME, "r");
    fp_ttlist = fopen(FILENAME_RSSTIME"_tmp", "r");
    
    if (fp_ttlist != NULL) {printf(MSG_ERROR"There is another process running.\n"); exit(1);}
    if (fp_list == NULL) {printf(MSG_ERROR"Cannot open RSSLIST.\n"); cleanenv();}
    memset(PUBLISH.ptitle, 0, sizeof(PUBLISH.ptitle));

    // process each line of RSS
    while (fgets(URL_RSS, sizeof(URL_RSS), fp_list) != NULL) {

        
        rm_newline(URL_RSS);
        is_NOUP = false;
        is_NOP = false;
        ptr = strchr(URL_RSS, ' ');         // get post title or NO upload flag(N)
        if (ptr != NULL) {
            
            *ptr++ = 0;                     // seperate URL
            if (!strcmp(ptr, "N")) {
                
                is_NOUP = true;

            } else {

                pptr = strchr(ptr, ' ');        // get order
                if (pptr != NULL) {

                    *pptr++ = 0;
                    PUBLISH.order = atoi(pptr);
                    
                    ppptr = strchr(pptr, ' ');
                    if (ppptr != NULL) {
                        
                        *ppptr++ = 0;
                        if (!strcmp(ppptr, "NP")) {
                            is_NOP = true;
                        }

                    }

                } else { printf(MSG_ERROR"Illegal format.\n"); cleanenv(); }
                strcpy(PUBLISH.ptitle, ptr);

            }
            
        } else { printf(MSG_ERROR"Illegal format.\n"); cleanenv(); }
        //printf(MSG_RSS"%s (%s)\n", URL_RSS, PUBLISH.ptitle);

        // get last publish timestamp
        if (fp_tlist != NULL) {
        
            fgets(buf, sizeof(buf), fp_tlist);
            rm_newline(buf);
            if (!strcmp(buf, ""))   PUBLISH.lastPub = CUR_TIME;
            else                    PUBLISH.lastPub = atol(buf);
        
        } else {PUBLISH.lastPub = CUR_TIME;}
        RSS_CNT++;
        getXML(URL_RSS); // get RSS push info
        
        // update last publish timestamp
        fp_ttlist = fopen(FILENAME_RSSTIME"_tmp", "a");
        if (fp_ttlist == NULL) {printf(MSG_ERROR"Cannot create RSS timestamp temp file.\n"); cleanenv(); }
        fprintf(fp_ttlist, "%ld\n", PUBLISH.lastPub);
        fclose(fp_ttlist);

    }
    fclose(fp_list);
    if (fp_tlist != NULL) fclose(fp_tlist);

}

/*
 *  Get Push RSS from RSS URL and parse contents.
 *  Input:  URL of RSS
 *  Output: none
 */   
void getXML(const char * const URL) {

    FILE * fp_xml;
    time_t temp;
    bool top = true, hasNew = false;
    char buf[BUF_SIZE];
    char * cmd = (char *)malloc(sizeof(char) * (len_rss + strlen(FILENAME_PXML) + strlen(URL)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "python3 -u %s \"%s\" 2> /dev/null", FILENAME_PXML, URL);
    fp_xml = popen(cmd, "r");
    if (fp_xml == NULL) {printf(MSG_ERROR"Get XML failed.\n"); cleanenv();}
    
    while (fgets(buf, sizeof(buf), fp_xml) != NULL) {
        
        rm_newline(buf);

	    // if fail to get XML
        if (top && buf[0] == '@') {
    
            char tmp[BUF_SIZE];
            printf(MSG_ERROR"Get XML failed.\n");
            memset(tmp, 0, sizeof(tmp));
            sprintf(tmp, "rm -f \"%s_tmp\"", FILENAME_RSSTIME);
            system(tmp);
            //printf(MSG_ERROR"Failed to get RSS (%s)"MSG_PUSH, buf + 1); 
            //push_notify(MSG_ERROR_N"Failed to get RSS.\n"); 
            cleanenv();
        
        }

        // parse item block
        if (strstr(buf, ITEM_HEAD)) {
            create_item(fp_xml);
            if (top) temp = PUBLISH.pubTime;
            top = false;
            if (PUBLISH.pubTime <= LAST_TIME && PUBLISH.pubTime <= PUBLISH.lastPub) break;
            if (!hasNew) {printf(MSG_RSS"%s (%s)\n", URL_RSS, PUBLISH.ptitle); printline();}
            if (hasNew)  printline();
            hasNew = true;
            task_notify();
            addDownload();
            TASK_CNT++;

        }        

    }
    if (hasNew) {RSS_PUB_CNT++; printdline();}
    PUBLISH.lastPub = temp;
    pclose(fp_xml);
    free(cmd);

}

/*
 *  Create an object to store each Push info.
 *  Input:  file descriptor of RSS
 *  Output: none
 */   
void create_item(FILE * fp) {

    char buf[BUF_SIZE];
    char * start, * end;
    char * title_head, * title_start, title_end;

    MODE = check_source(URL_RSS);

    if (MODE == MODE_BANGUMI) {

        while (fgets(buf, sizeof(buf), fp) != NULL) {
            
            rm_newline(buf);

            // read title
            if (strstr(buf, "<title>")) {

                //fgets(buf, sizeof(buf), fp);
                rm_newline(buf);
                start = strstr(buf, "CDATA[") + strlen("CDATA[");
                end = strstr(buf, "]]>");
                memset(PUBLISH.title, 0, sizeof(PUBLISH.title));
                strncpy(PUBLISH.title, start, end - start);

            } 
            // read link
            else if (strstr(buf, "<link>")) {

                start = strchr(buf, '>') + 1;
                end = strrchr(buf, '<');
                memset(PUBLISH.link, 0, sizeof(PUBLISH.link));
                strncpy(PUBLISH.link, start, end - start); 

            }
            // read pubDate
            else if (strstr(buf, "<pubDate>")) {

                char temp[BUF_SIZE];
                start = strchr(buf, '>') + 1;
                end = strrchr(buf, '<');
                memset(temp, 0, sizeof(temp));
                strncpy(temp, start, end - start); 
                PUBLISH.pubTime = translate_time(temp);

            }
            // read torrent link
            else if (strstr(buf, "<enclosure")) {

                start = strstr(buf, "url=") + 5;
                end = strchr(start, '"');
                memset(PUBLISH.torrent, 0, sizeof(PUBLISH.torrent));
                strncpy(PUBLISH.torrent, start, end - start);

            }
            else if (strstr(buf, ITEM_END)) break;

        }
    
    } else if (MODE == MODE_NYAA) {

        while (fgets(buf, sizeof(buf), fp) != NULL) {
            
            rm_newline(buf);

            // read title
            if (strstr(buf, "<title>")) {
                
                start = strchr(buf, '>') + 1;
                end = strrchr(buf, '<');
                memset(PUBLISH.title, 0, sizeof(PUBLISH.title));
                strncpy(PUBLISH.title, start, end - start);

            } 
            // read link
            else if (strstr(buf, "<guid")) {

                start = strchr(buf, '>') + 1;
                end = strrchr(buf, '<');
                memset(PUBLISH.link, 0, sizeof(PUBLISH.link));
                strncpy(PUBLISH.link, start, end - start); 

            }
            // read pubDate
            else if (strstr(buf, "<pubDate>")) {

                char temp[BUF_SIZE];
                start = strchr(buf, '>') + 1;
                end = strrchr(buf, '<');
                memset(temp, 0, sizeof(temp));
                strncpy(temp, start, end - start); 
                PUBLISH.pubTime = translate_time(temp);

            }
            // read torrent link
            else if (strstr(buf, "<link>")) {

                start = strchr(buf, '>') + 1;
                end = strrchr(buf, '<');
                memset(PUBLISH.torrent, 0, sizeof(PUBLISH.torrent));
                strncpy(PUBLISH.torrent, start, end - start);

            }
            else if (strstr(buf, ITEM_END)) break;

        }

    }

}

/*
 *  (Deprecated) Get torrent link in publish website for DMHY.
 *  Input:  none
 *  Output: none
 */   
void gettorrent(void) {

    FILE * fp_torrent, * fp_filename;
    char buf[BUF_SIZE];
    char * start, * end;
    char * cmd = (char *)malloc(sizeof(char) * (len_torrent + strlen(PUBLISH.link)));
    
    // find torrent link in publish website
    memset(cmd, 0, sizeof(cmd));
    strcpy(cmd, "wget -qO- '");
    strcat(cmd, PUBLISH.link);
    strcat(cmd, "'|grep 會員專用連接");
    
    fp_torrent = popen(cmd, "r");
    if (fp_torrent == NULL) {printf(MSG_ERROR"Cannot get torrent.\n"); cleanenv();}
    while (fgets(buf, sizeof(buf), fp_torrent) != NULL) {
        
        rm_newline(buf);
        start = strchr(buf, '=') + 2;
        end = strrchr(buf, '"');
        memset(PUBLISH.torrent, 0, sizeof(PUBLISH.torrent));
        strcpy(PUBLISH.torrent, "https:");
        strncat(PUBLISH.torrent, start, end - start);
        printf(MSG_TORRENT"%s\n", PUBLISH.torrent); 

    }
    pclose(fp_torrent);
    free(cmd);

}

/*
 *  Create download task on Aria2. (use HTTP request)
 *  Input:  none
 *  Output: none
 */ 
void addDownload(void) {

    FILE * fp_http_req, * fp_filename, * fp_config, * fp_post;
    bool fin;
    int cnt;
    char * start;
    char cmd[BUF_SIZE], buf[BUF_SIZE], torrent_name[BUF_SIZE], code[4];
    time_t dl_start;
    
    // send HTTP request to Aria2
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "curl -m 30 -sX POST \"%s\" -w \" Status: %{http_code}\" " \
                                      "-d '{\"jsonrpc\":\"%s\"," \
                                           "\"method\":\"%s\"," \
                                           "\"id\":\"%s\"," \
                                           "\"params\":[\"token:%s\"," \
                                                      "[\"%s\"]]}' " \
                                     "--cacert %s", SERVER_URL, JSONRPC, METHOD, ID, ARIA2_TOKEN, PUBLISH.torrent, CERT_PATH);
    fp_http_req = popen(cmd, "r");
    if (fp_http_req == NULL) {printf(MSG_ERROR"Send HTTP request failed.\n"); cleanenv();}
    fgets(buf, sizeof(buf), fp_http_req);
    memset(code, 0, sizeof(code));
    start = strrchr(buf, ':') + 1;
    strcpy(code, start);
    if (atoi(code) == HTTPCODE_OK)  printf(MSG_NOTICE""MSG_ADDTASK""MSG_SUCCESS"\n");
    else                           {printf(MSG_NOTICE""MSG_ADDTASK""MSG_FAIL""MSG_PUSH); push_notify(MSG_ERROR_N""MSG_ADDTASK""MSG_FAIL_N"\n"); cleanenv();}
    pclose(fp_http_req);
    time(&dl_start); // get download start time

    // get torrent name
    memset(cmd, 0, sizeof(cmd));
    if (MODE == MODE_NYAA)          sprintf(cmd, "%s %s", FILENAME_GETFNAME, PUBLISH.torrent);
    else if (MODE == MODE_BANGUMI)  sprintf(cmd, "basename \"$(echo \"%s\")\"", PUBLISH.torrent);
    fp_filename = popen(cmd, "r");
    if (fp_filename == NULL) {printf(MSG_ERROR"Cannot get torrent filename.\n"); cleanenv();}
    fgets(torrent_name, sizeof(torrent_name), fp_filename);
    rm_newline(torrent_name);
    pclose(fp_filename);
    fp_filename = NULL;
    
    // wait until torrent file downloaded
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "transmission-show \"%s%s\" &> /dev/null;echo $?", DLDIR, torrent_name);
    while (1) {

        FILE * fpfp;
        fpfp = popen(cmd, "r");
        if (fpfp == NULL) {printf(MSG_ERROR"Cannot get torrent filename.\n"); cleanenv();}
        fgets(buf, sizeof(buf), fpfp);
        //printf("buf=%s\n", buf);
        pclose(fpfp);
        rm_newline(buf);
        if (buf[0] == '0') break;
        usleep(SLEEP_TIME);

    }
    
    // get filename
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "transmission-show \"%s%s\"|grep Name|head -1", DLDIR, torrent_name);
    fp_filename = popen(cmd, "r");
    fgets(buf, sizeof(buf), fp_filename);
    rm_newline(buf);
    start = strchr(buf, ':') + 2;
    strcpy(PUBLISH.filename, start);
    pclose(fp_filename);

    if (!is_NOUP) {
        
        // create .NP to identify that script will no post this file to TSDM.
        if (is_NOP) {
            memset(cmd, 0, sizeof(cmd));
            sprintf(cmd, "rm -f '%s%s.NP';sudo -u apache touch '%s%s.NP'", DLDIR, PUBLISH.filename, DLDIR, PUBLISH.filename);
            system(cmd);
        }

        // create .upload to identify that script will upload this file to baidu.
        memset(cmd, 0, sizeof(cmd));
        sprintf(cmd, "rm -f '%s%s.upload';sudo -u apache touch '%s%s.upload'", DLDIR, PUBLISH.filename, DLDIR, PUBLISH.filename);
        system(cmd);

        // output post title to upload config
        memset(cmd, 0, sizeof(cmd));
        sprintf(cmd, "%s%s.upload", DLDIR, PUBLISH.filename);
        fp_config = fopen(cmd, "a");
        if (fp_config == NULL) {printf(MSG_ERROR"Cannot open upload config.\n"); cleanenv();}
        fprintf(fp_config, "%s\n", PUBLISH.ptitle);
        fprintf(fp_config, "%s\n", PUBLISH.link);       // publish URL
        strftime(buf, BUF_SIZE, "%Y/%m/%d %H:%M:%S (%a)", localtime(&PUBLISH.pubTime));
        fprintf(fp_config, "%s\n", buf);                // publish date

        // output sub-post content to upload config
        memset(cmd, 0, sizeof(cmd));
        strcpy(cmd, POST_FILE);
        fp_post = fopen(cmd, "r");
        if (fp_post == NULL) {printf(MSG_ERROR"Cannot open post content.\n"); cleanenv();}

        cnt = 0;
        fin = false;
        while (fgets(buf, sizeof(buf), fp_post) != NULL) {
            
            rm_newline(buf);
            if (strcmp(buf, POST_DELIMIT) == 0) cnt++;
            if (cnt == PUBLISH.order) {
                
                while (1) {

                    fgets(buf, sizeof(buf), fp_post);
                    rm_newline(buf);
                    if (strcmp(buf, POST_DELIMIT) == 0) {fin = true; break;}
                    fprintf(fp_config, "%s\n", buf);

                }
                if (fin) break;
                
            }
            
        }
        fclose(fp_post);

        // output start download time to upload config
        fprintf(fp_config, "%ld ", dl_start);
        fclose(fp_config);

    }

}

/*
 *  Show the last checkpoint time.
 *  Input:  none
 *  Output: none
 */ 
void show_lasttime(void) {

    FILE * fp_time;
    char buf[BUF_SIZE];

    fp_time = fopen(TIMESTAMP_FILE, "r");
    if (fp_time == NULL) {

        // if no checkpoint exist
        printf("First Run.\n");
        fp_time = fopen(TIMESTAMP_FILE, "w");
        if (fp_time == NULL) {printf(MSG_ERROR"Cannot create checkpoint.\n"); cleanenv();}
        fprintf(fp_time, "%ld\n", CUR_TIME);
        LAST_TIME = CUR_TIME;
        
    } else {

        // read checkpoint
        fgets(buf, sizeof(buf), fp_time);
        rm_newline(buf);
        LAST_TIME = atol(buf);

    }

    fclose(fp_time);
    printf(MSG_LASTIME"%s", asctime(localtime(&LAST_TIME)));

}

/*
 *  Update the checkpoint with current time.
 *  Input:  none
 *  Output: none
 */ 
void update_checkpoint(void) {

    FILE * fp_time;
    fp_time = fopen(TIMESTAMP_FILE, "w");
    if (fp_time == NULL) {printf(MSG_ERROR"Cannot open checkpoint file.\n"); cleanenv();}
    fprintf(fp_time, "%ld\n", CUR_TIME);
    fclose(fp_time);

}

void task_notify(void) {

    char buf[BUF_SIZE], msg[BUF_SIZE];
    strftime(buf, BUF_SIZE, "%Y/%m/%d %H:%M:%S (%a)", localtime(&PUBLISH.pubTime));
    printf(MSG_TITLE"%s\n", PUBLISH.title);
    printf(MSG_PUBDATE"%s\n", buf);
    printf(MSG_TORRENT"%s\n", PUBLISH.torrent); 
    sprintf(msg, "\n[Title]： %s\n[PubDate]： %s\n[URL]： %s", PUBLISH.title, buf, PUBLISH.link);
    push_notify(msg);

}

/*
 *  Show information of Push info and push notification to LINE.
 *  Input:  none
 *  Output: none
 */   
void push_notify(const char const * msg) {

    FILE * fp_notify;
    char code[4], buf[BUF_SIZE];
    char * start, * end;
    char * cmd = (char *)malloc(sizeof(char) * (len_notify + strlen(LINE_TOKEN) + strlen(LINE_API) + BUF_SIZE));
    
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "curl -m 15 -sX POST '%s'" \
                    " --header 'Content-Type: application/x-www-form-urlencoded'" \
                    " --header 'Authorization: Bearer %s'" \
                    " --data-urlencode 'Message=%s';echo $?", LINE_API, LINE_TOKEN, msg);
    fp_notify = popen(cmd, "r");
    if (fp_notify == NULL) {printf(MSG_ERROR"Send notify to LINE failed.\n"); cleanenv();}
    fgets(buf, sizeof(buf), fp_notify);
    rm_newline(buf);
    if (buf[0] != '{') printf(MSG_ERROR""MSG_LINE""MSG_FAIL"\n");   // connection timeout
    start = strstr(buf, "status\":") + strlen("status\":");
    end = strchr(buf, ',');
    memset(code, 0, sizeof(code));
    strncpy(code, start, end - start);
    if (atoi(code) == HTTPCODE_OK) printf(MSG_NOTICE""MSG_LINE""MSG_SUCCESS"\n");
    else                           printf(MSG_ERROR""MSG_LINE""MSG_FAIL"\n");
    fclose(fp_notify);
    free(cmd);
    
}

int check_source(const char const * str) {

    char * start, * end;
    char buf[BUF_SIZE];

    start = strchr(str, ':') + 3;
    end = strchr(start, '/');
    memset(buf, 0, sizeof(buf));
    strncpy(buf, start, end - start);
    if (!strcmp(buf, BANGUMI)) return MODE_BANGUMI;
    else if (!strcmp(buf, NYAA)) return MODE_NYAA;
    else {printf(MSG_ERROR"This site (%s) is not support yet.\n", buf); cleanenv();};

}

void convert_time(char * str, time_t t) {

    FILE * fp_time;
    char buf[BUF_SIZE];
    
    memset(buf, 0, sizeof(buf));
    sprintf(buf, "echo %ld | %s", t, FILENAME_CTIME);
    fp_time = popen(buf, "r");
    if (fp_time == NULL) {printf(MSG_ERROR"Cannot convert time.\n"); cleanenv();}
    fgets(buf, sizeof(buf), fp_time);
    rm_newline(buf);
    strcpy(str, buf);

}

time_t translate_time(const char const * str) {

    char * start, * end;
    char temp[BUF_SIZE];
    int mday, mon, year, hour;
    TIME T;

    T.tm_isdst = 0;

    // parse mday
    start = strchr(str, ' ') + 1;
    end = strchr(start, ' ');
    memset(temp, 0, sizeof(temp));
    strncpy(temp, start, end - start); 
    T.tm_mday = atoi(temp);

    // parse mon
    start = end + 1;
    end = strchr(start, ' ');
    memset(temp, 0, sizeof(temp));
    strncpy(temp, start, end - start);
    T.tm_mon = number_for_key(temp);
    
    // parse year
    start = end + 1;
    end = strchr(start, ' ');
    memset(temp, 0, sizeof(temp));
    strncpy(temp, start, end - start);
    T.tm_year = atoi(temp) - 1900;
    
    // parse hour
    start = end + 1;
    end = strchr(start, ':');
    memset(temp, 0, sizeof(temp));
    strncpy(temp, start, end - start);
    T.tm_hour = atoi(temp);

    // parse min
    start = end + 1;
    end = strchr(start, ':');
    memset(temp, 0, sizeof(temp));
    strncpy(temp, start, end - start);
    T.tm_min = atoi(temp);

    // parse sec
    start = end + 1;
    end = strchr(start, ' ');
    memset(temp, 0, sizeof(temp));
    strncpy(temp, start, end - start);
    T.tm_sec = atoi(temp);

    // check timezone
    start = end + 1;
    memset(temp, 0, sizeof(temp));
    strcpy(temp, start);
    if (!strcmp(temp, "GMT")) {

        // apply timezone
        T.tm_hour += TIMEZONE;
        if (T.tm_hour > 23) {

            T.tm_hour %= 24;
            T.tm_mday++;
            if (T.tm_mday > 31) {

                T.tm_mday %= 31;
                T.tm_mon++;
                if (T.tm_mon > 11) {

                    T.tm_mon %= 12;
                    T.tm_year++;

                }

            }

        } else if (T.tm_hour < 0) {

            T.tm_mday--;
            T.tm_hour += 24;
            if (T.tm_mday < 1) {

                T.tm_mon--;
                T.tm_mday += 31;
                if (T.tm_mon < 0) {

                    T.tm_year--;
                    T.tm_mon += 12;
                    
                }

            }
            
        }

    }
    PUBLISH.pubTime = mktime(&T);   // get target timestamp

}

/*
 *  Remove the string with newline character (include DOS/UNIX)
 *  Input:  target string
 *  Output: none
 */ 
void rm_newline(char * str) {

    str[strcspn(str, "\r\n")] = 0;

}

/*
 *  Custom dictionary implementation. (for month in letter to number)
 *  Input:  key
 *  Output: value
 */ 
int number_for_key(char * key) {

    int i = 0;
    char * name = MONTH[i].str;

    while (name) {

        if (strcmp(name, key) == 0) return MONTH[i].n;
        name = MONTH[++i].str;

    }
    return -1;

}

/*
 *  Remove duplicated whitespace in a string.
 *  Input:  target string
 *  Output: none
 */ 
void rmspace(char * str){					

    int wcnt = 0, scnt = 0;
	char * start = str, * end = str, * tmp = (char *)malloc(sizeof(char) * (strlen(str) + 1));
	
    memset(tmp, 0, sizeof(tmp));
    while (1) {

        if (*end == 0) break;
        
        scnt = 0;
        if (*end == ' ') {
            
            end++;
            while (1) {

                if (*end != ' ') {
                    
                    strcat(tmp, " ");
                    start = end;
                    break;

                }
                end++;
                
            }

        } else {

            scnt++;
            end++;
            while (1) {

                if (*end == 0 || *end == ' ') {
                    
                    strncat(tmp, start, scnt);
                    start = end;
                    break;

                }
                scnt++;
                end++;

            }
        }

    }

    memset(str, 0, sizeof(tmp) + 1);
    strcpy(str, tmp);
    free(tmp);
	
}

void cleanenv(void) {

    system("rm -f "FILENAME_RSSTIME"_tmp");
    exit(1);

}

void printline(void) { printf(LINE""LINE"\n"); }
void printdline(void) { printf(DLINE""DLINE""DLINE"\n"); }
