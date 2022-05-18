#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <wchar.h>
#include <time.h>

#define BUF_SIZE            1024
#define SLEEP_TIME          500
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
#define SERVER_URL          "https://kdrive.ga:6800/jsonrpc"

#define JSONRPC             "2.0"
#define METHOD              "aria2.addUri"
#define ID                  "root"

#define CERT_PATH           "/etc/aria2/intermediate.pem"
#define DLDIR               "/NAS/Aria2/"
#define ARIA2_CONFIG        "/etc/aria2/aria2.conf"
#define TIMESTAMP_FILE      "/etc/aria2/checkpoint"
#define FILENAME_LIST       "/etc/aria2/RSSLIST.txt"
#define FILENAME_RSSTIME    "/etc/aria2/RSSLIST_timestamp"
#define POST_FILE           "/etc/aria2/post.txt"
#define PRETTY_XML          "/etc/aria2/prettyXML.py"
#define CMD_MOVETS          "mv "FILENAME_RSSTIME"_tmp "FILENAME_RSSTIME

#define POST_DELIMIT        "$$$$$"
#define ITEM_HEAD           "<item>"
#define ITEM_END            "</item>"
#define TITLE_HEAD          "<title>"
#define LINK_HEAD           "<link>"
#define PUBDATE_HEAD        "<pubDate>"
#define ENCLOSURE           "<enclosure"

#define MSG_SUCCESS         COLOR_GREEN"Success"COLOR_RESET
#define MSG_FAIL            COLOR_RED"Fail"COLOR_RESET
#define MSG_ERROR           COLOR_RED"[ERROR]: "COLOR_RESET
#define MSG_NOTICE          COLOR_LIGHTBLUE"[Notice]:        "COLOR_RESET
#define MSG_RSS             COLOR_YELLOW"[RSS PATH]:      "COLOR_RESET
#define MSG_TITLE           COLOR_PURPLE"[Title]:         "COLOR_RESET
#define MSG_PUBDATE         COLOR_PURPLE"[PubDate]:       "COLOR_RESET
#define MSG_TORRENT         COLOR_PURPLE"[Torrent Link]:  "COLOR_RESET
#define MSG_CURTIME         "[Current Time]:  "
#define MSG_LASTIME         "[Check Time]:    "
#define MSG_LINE            "{PUSH to LINE}="
#define MSG_ADDTASK         "{Add torrent to Aria2}="
#define LINE                "---------------------------------------------"
#define DLINE               "============================================="


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

int         RSS_CNT         = 0;
int         RSS_PUB_CNT     = 0;
char        URL_RSS         [BUF_SIZE];
char        LINE_TOKEN      [BUF_SIZE];
char        ARIA2_TOKEN     [BUF_SIZE];
time_t      CUR_TIME;
time_t      LAST_TIME;
time_t      DL_START;
publish     PUBLISH;

const int   len_rss         = strlen("python3 /etc/aria2/test.py ") + 1;
const int   len_torrent     = strlen("wget -qO- '' | grep 會員專用連接") + 1;
const int   len_filename    = strlen("transmission-show  | grep Name | head -1") + 1;
const int   len_filename_c  = strlen("transmission-show \"\" &> /dev/null;echo $?") + 1;
const int   len_createfile  = strlen("rm -f '.upload'sudo -u apache touch '.upload'") + 1;
const int   len_notify      = strlen("curl -sX POST ''" \
                                         " --header 'Content-Type: application/x-www-form-urlencoded'" \
                                         " --header 'Authorization: Bearer '" \
                                         " --data-urlencode 'Message='") + 1;
const int   len_req         = strlen("curl -X POST ''" \
                                          "-w \" Status: %{http_code}\"" \
                                          "-d '{\"jsonrpc\": \"\"," \
                                               "\"method\": \"\"," \
                                               "\"id\": \"\"," \
                                               "\"params\": [\"token:\"," \
                                                           "[\"\"]]}'" \
                                          "--cacert ") + 1;

void    readToken          (void);
void    getRSS             (void);
void    getXML             (const char * const);
void    rm_newline         (char *);
void    create_item        (FILE *);
void    push_notify        (void);
void    gettorrent         (void);
void    addDownload        (void);
void    show_lasttime      (void);
void    update_checkpoint  (void);
time_t  translate_time     (const char const *);
int     number_for_key     (char *);
void    rmspace            (char *);
void    printline          (void);
void    printdline         (void);


int main(int argc, char *argv[]) {

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
    system(CMD_MOVETS);
    printf("Checked %d RSS, and %d has published new episode.\n", RSS_CNT, RSS_PUB_CNT);
    printdline();
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
    if (fp_config == NULL) {printf(MSG_ERROR"Cannot open aria2 config.\n"); exit(1);}
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
    if (fp_list == NULL) {printf(MSG_ERROR"Cannot open RSSLIST.\n"); exit(1);}
    memset(PUBLISH.ptitle, 0, sizeof(PUBLISH.ptitle));

    // process each line of RSS
    while (fgets(URL_RSS, sizeof(URL_RSS), fp_list) != NULL) {

        
        rm_newline(URL_RSS);
        ptr = strchr(URL_RSS, ' ');         // get post title
        if (ptr != NULL) {
            
            *ptr++ = 0;                     // seperate URL
            pptr = strchr(ptr, ' ');        // get order
            if (pptr != NULL) {

                *pptr++ = 0;
                PUBLISH.order = atoi(pptr);                 

            } else { printf(MSG_ERROR"Illegal format.\n"); exit(1); }
            strcpy(PUBLISH.ptitle, ptr);

        } else { printf(MSG_ERROR"Illegal format.\n"); exit(1); }
        //printf(MSG_RSS"%s (%s)\n", URL_RSS, PUBLISH.ptitle);

        // get last publish timestamp
        if (fp_tlist != NULL) {
        
            fgets(buf, sizeof(buf), fp_tlist);
            rm_newline(buf);
            PUBLISH.lastPub = atol(buf);
        
        } else {PUBLISH.lastPub = CUR_TIME;}
        //printline();
        RSS_CNT++;
        getXML(URL_RSS); // get RSS push info

        // update last publish timestamp
        fp_ttlist = fopen(FILENAME_RSSTIME"_tmp", "a+");
        if (fp_ttlist == NULL) {printf(MSG_ERROR"Cannot create RSS timestamp temp file.\n"); exit(1); }
        fprintf(fp_ttlist, "%ld\n", PUBLISH.lastPub);
        fclose(fp_ttlist);
        //printdline();

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
    bool top = true;
    char buf[BUF_SIZE];
    char * cmd = (char *)malloc(sizeof(char) * (len_rss + strlen(PRETTY_XML) + strlen(URL)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "python3 %s \"%s\"", PRETTY_XML, URL);
    fp_xml = popen(cmd, "r");
    if (fp_xml == NULL) {printf(MSG_ERROR"Get XML failed.\n"); exit(1);}
    while (fgets(buf, sizeof(buf), fp_xml) != NULL) {
        
        rm_newline(buf);

        // parse item block
        if (strstr(buf, ITEM_HEAD)) {
            create_item(fp_xml);
            if (top) temp = PUBLISH.pubTime;
            top = false;
            if (PUBLISH.pubTime <= LAST_TIME && PUBLISH.pubTime <= PUBLISH.lastPub) break;
            RSS_PUB_CNT++;
            printf(MSG_RSS"%s (%s)\n", URL_RSS, PUBLISH.ptitle);
            push_notify();
            addDownload();
            printline();
            printdline();

        }        

    }
    PUBLISH.lastPub = temp;
    pclose(fp_xml);
    free(cmd);

}

/*
 *  Create an object to store each Push info. (for Bangumi)
 *  Input:  file descriptor of RSS
 *  Output: none
 */   
void create_item(FILE * fp) {

    char buf[BUF_SIZE];
    char * start, * end;

    while (fgets(buf, sizeof(buf), fp) != NULL) {
        
        rm_newline(buf);

        // read title
        if (strstr(buf, TITLE_HEAD)) {

            fgets(buf, sizeof(buf), fp);
            rm_newline(buf);
            start = strstr(buf, "CDATA[") + strlen("CDATA[");
            end = strstr(buf, "]]>");
            memset(PUBLISH.title, 0, sizeof(PUBLISH.title));
            strncpy(PUBLISH.title, start, end - start);

        } 
        // read link
        else if (strstr(buf, LINK_HEAD)) {

            start = strchr(buf, '>') + 1;
            end = strrchr(buf, '<');
            memset(PUBLISH.link, 0, sizeof(PUBLISH.link));
            strncpy(PUBLISH.link, start, end - start); 

        }
        // read pubDate
        else if (strstr(buf, PUBDATE_HEAD)) {

            char temp[BUF_SIZE];
            start = strchr(buf, '>') + 1;
            end = strrchr(buf, '<');
            memset(temp, 0, sizeof(temp));
            strncpy(temp, start, end - start); 
            PUBLISH.pubTime = translate_time(temp);

        }
        else if (strstr(buf, ENCLOSURE)) {

            start = strstr(buf, "url=") + 5;
            end = strchr(buf, '>') - 2;
            memset(PUBLISH.torrent, 0, sizeof(PUBLISH.torrent));
            strncpy(PUBLISH.torrent, start, end - start);

        }
        else if (strstr(buf, ITEM_END)) break;

    }

}

/*
 *  Show information of Push info and push notification to LINE.
 *  Input:  none
 *  Output: none
 */   
void push_notify(void) {

    FILE * fp_notify;
    char msg[BUF_SIZE], buf[BUF_SIZE], code[4];
    char * start, * end;
    char * cmd = (char *)malloc(sizeof(char) * (len_notify + strlen(LINE_TOKEN) + strlen(LINE_API) + BUF_SIZE));
    
    memset(cmd, 0, sizeof(cmd));
    memset(msg, 0, sizeof(msg));
    memset(buf, 0, sizeof(buf));

    strftime(buf, BUF_SIZE, "%Y/%m/%d %H:%M:%S (%a)", localtime(&PUBLISH.pubTime));
    printf(MSG_TITLE"%s\n", PUBLISH.title);
    printf(MSG_PUBDATE"%s\n", buf);
    printf(MSG_TORRENT"%s\n", PUBLISH.torrent); 
    sprintf(msg, "\n[Title]： %s\n[PubDate]： %s\n[URL]： %s", PUBLISH.title, buf, PUBLISH.link);
    sprintf(cmd, "curl -sX POST '%s'" \
                    " --header 'Content-Type: application/x-www-form-urlencoded'" \
                    " --header 'Authorization: Bearer %s'" \
                    " --data-urlencode 'Message=%s'", LINE_API, LINE_TOKEN, msg);

    fp_notify = popen(cmd, "r");
    if (fp_notify == NULL) {printf(MSG_ERROR"Send notify to LINE failed.\n"); exit(1);}
    fgets(buf, sizeof(buf), fp_notify);
    rm_newline(buf);
    start = strstr(buf, "status\":") + strlen("status\":");
    end = strchr(buf, ',');
    memset(code, 0, sizeof(code));
    strncpy(code, start, end - start);
    if (atoi(code) == HTTPCODE_OK) printf(MSG_NOTICE""MSG_LINE""MSG_SUCCESS"\n");
    else                           printf(MSG_ERROR""MSG_LINE""MSG_FAIL"\n");
    fclose(fp_notify);
    free(cmd);
    
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
    if (fp_torrent == NULL) {printf(MSG_ERROR"Cannot get torrent.\n"); exit(1);}
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
    char * cmd, * start;
    char buf[BUF_SIZE], torrent_name[BUF_SIZE], code[4];
    time_t dl_start;
    
    // send HTTP request to Aria2
    cmd = (char *)malloc(sizeof(char) * (len_req + strlen(SERVER_URL) + strlen(JSONRPC) + strlen(METHOD) \
                                                 + strlen(ID) + strlen(ARIA2_TOKEN) + strlen(PUBLISH.torrent) + strlen(CERT_PATH)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "curl -sX POST \"%s\" -w \" Status: %{http_code}\" " \
                                      "-d '{\"jsonrpc\":\"%s\"," \
                                           "\"method\":\"%s\"," \
                                           "\"id\":\"%s\"," \
                                           "\"params\":[\"token:%s\"," \
                                                      "[\"%s\"]]}' " \
                                     "--cacert %s", SERVER_URL, JSONRPC, METHOD, ID, ARIA2_TOKEN, PUBLISH.torrent, CERT_PATH);
    fp_http_req = popen(cmd, "r");
    if (fp_http_req == NULL) {printf(MSG_ERROR"Send HTTP request failed.\n"); exit(1);}
    fgets(buf, sizeof(buf), fp_http_req);
    memset(code, 0, sizeof(code));
    start = strrchr(buf, ':') + 1;
    strcpy(code, start);
    if (atoi(code) == HTTPCODE_OK) printf(MSG_NOTICE""MSG_ADDTASK""MSG_SUCCESS"\n");
    else                           printf(MSG_NOTICE""MSG_ADDTASK""MSG_FAIL"\n");
    pclose(fp_http_req);
    time(&dl_start); // get download start time

    // wait until torrent file downloaded
    start = strrchr(PUBLISH.torrent, '/') + 1;
    strcpy(torrent_name, start);
    cmd = (char *)malloc(sizeof(char) * (len_filename_c + strlen(torrent_name) + strlen(DLDIR)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "transmission-show \"%s%s\" &> /dev/null;echo $?", DLDIR, torrent_name);
    while (1) {

        fp_filename = popen(cmd, "r");
        if (fp_filename == NULL) {printf(MSG_ERROR"Cannot get torrent filename.\n"); exit(1);}
        fgets(buf, sizeof(buf), fp_filename);
        pclose(fp_filename);
        rm_newline(buf);
        if (buf[0] == '0') break;
        usleep(SLEEP_TIME);

    }
    free(cmd);
    
    // get filename
    cmd = (char *)malloc(sizeof(char) * (len_filename + strlen(torrent_name) + strlen(DLDIR)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "transmission-show \"%s%s\"|grep Name|head -1", DLDIR, torrent_name);
    fp_filename = popen(cmd, "r");
    fgets(buf, sizeof(buf), fp_filename);
    rm_newline(buf);
    start = strchr(buf, ':') + 2;
    strcpy(PUBLISH.filename, start);
    pclose(fp_filename);
    free(cmd);

    // create .upload to identify that script will upload this file to baidu.
    cmd = (char *)malloc(sizeof(char) * (len_createfile + strlen(PUBLISH.filename) * 2 + strlen(DLDIR) * 2));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "rm -f '%s%s.upload';sudo -u apache touch '%s%s.upload'", DLDIR, PUBLISH.filename, DLDIR, PUBLISH.filename);
    system(cmd);

    // output post title to upload config
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "%s%s.upload", DLDIR, PUBLISH.filename);
    fp_config = fopen(cmd, "a");
    if (fp_config == NULL) {printf(MSG_ERROR"Cannot open upload config.\n"); exit(1);}
    fprintf(fp_config, "%s\n", PUBLISH.ptitle);

    // output sub-post content to upload config
    memset(cmd, 0, sizeof(cmd));
    strcpy(cmd, POST_FILE);
    fp_post = fopen(cmd, "r");
    if (fp_post == NULL) {printf(MSG_ERROR"Cannot open post content.\n"); exit(1);}

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
    free(cmd);

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
        if (fp_time == NULL) {printf(MSG_ERROR"Cannot create checkpoint.\n"); exit(1);}
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
    if (fp_time == NULL) {printf(MSG_ERROR"Cannot open checkpoint file.\n"); exit(1);}
    fprintf(fp_time, "%ld\n", CUR_TIME);
    fclose(fp_time);

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

void printline(void) { printf(LINE""LINE"\n"); }
void printdline(void) { printf(DLINE""DLINE""DLINE"\n"); }