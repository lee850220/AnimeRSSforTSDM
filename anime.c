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

#define SERVER_URL          "https://kdrive.ga:6800/jsonrpc"
#define JSONRPC             "2.0"
#define METHOD              "aria2.addUri"
#define ID                  "root"
#define CERT_PATH           "/etc/aria2/intermediate.pem"
#define DLDIR               "/NAS/Aria2/"
#define ARIA2_CONFIG        "/etc/aria2/aria2.conf"
#define TIMESTAMP_FILE      "/etc/aria2/checkpoint"
#define FILENAME_LIST       "/etc/aria2/RSSLIST.txt"
#define PRETTY_XML          "/etc/aria2/prettyXML.py"

#define LINE_API            "https://notify-api.line.me/api/notify"

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

    char title      [BUF_SIZE];
    char link       [BUF_SIZE];
    char pubDate    [BUF_SIZE];
    char torrent    [BUF_SIZE];
    char filename   [BUF_SIZE];

} publish, * publish_ptr;

typedef struct tm TIME, * TIME_ptr;

char        URL_RSS         [BUF_SIZE];
char        LINE_TOKEN      [BUF_SIZE];
char        ARIA2_TOKEN     [BUF_SIZE];
time_t      CUR_TIME;
time_t      LAST_TIME;
publish     PUBLISH;

const int   len_rss         = strlen("python3 /etc/aria2/test.py ") + 1;
const int   len_torrent     = strlen("wget -qO- '' | grep 會員專用連接") + 1;
const int   len_filename    = strlen("transmission-show  | grep Name | head -1") + 1;
const int   len_filename_c  = strlen("transmission-show \"\" &> /dev/null;echo $?") + 1;
const int   len_createfile  = strlen("touch '.upload'") + 1;
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

void readToken          (void);
void getRSS             (void);
void getXML             (const char * const);
void rm_newline         (char *);
void create_item        (FILE *);
void push_notify        (void);
void gettorrent         (void);
void addDownload        (void);
bool checknew           (void);
void show_lasttime      (void);
void update_checkpoint  (void);
int  number_for_key     (char *);
void rmspace            (char *);
void printline          (void);
void printdline         (void);


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
    if (fp_config == NULL) exit(1);
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

    FILE * fp_list;

    fp_list = fopen(FILENAME_LIST, "r");
    if (fp_list == NULL) exit(1);

    // process each line of RSS
    while (fgets(URL_RSS, sizeof(URL_RSS), fp_list) != NULL) {

        char * ptr;
        rm_newline(URL_RSS);
        ptr = strchr(URL_RSS, ' ');
        if (ptr != NULL) {
            
            *ptr++ = 0;
            printf(MSG_RSS"%s (%s)\n", URL_RSS, ptr);

        } else { printf(MSG_RSS"%s\n", URL_RSS); }
        printline();
        rm_newline(URL_RSS);
        getXML(URL_RSS); // get RSS push info
        printdline();

    }
    fclose(fp_list);

}

/*
 *  Get Push RSS from RSS URL and parse contents.
 *  Input:  URL of RSS
 *  Output: none
 */   
void getXML(const char * const URL) {

    FILE * fp_xml;
    char buf[BUF_SIZE];
    char * cmd = (char *)malloc(sizeof(char) * (len_rss + strlen(PRETTY_XML) + strlen(URL)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "python3 %s \"%s\"", PRETTY_XML, URL);
    fp_xml = popen(cmd, "r");
    if (fp_xml == NULL) exit(1);
    while (fgets(buf, sizeof(buf), fp_xml) != NULL) {
        
        rm_newline(buf);

        // parse item block
        if (strstr(buf, ITEM_HEAD)) {
            create_item(fp_xml);
            if (!checknew()) break;
            push_notify();
            addDownload();
            printf("\n");

        }

    }
    pclose(fp_xml);
    free(cmd);

}

/*
void create_item(FILE * fp) {

    char buf[BUF_SIZE];
    char * start, * end;

    while (fgets(buf, sizeof(buf), fp) != NULL) {
        
        rm_newline(buf);

        // read title
        if (strncmp(buf, TITLE_HEAD, strlen(TITLE_HEAD)) == 0) {

            start = strstr(buf, "CDATA[") + strlen("CDATA[");
            end = strstr(buf, "]></title>") - 1;
            memset(PUBLISH.title, 0, sizeof(PUBLISH.title));
            strncpy(PUBLISH.title, start, end - start);

        } 
        // read link
        else if (strncmp(buf, LINK_HEAD, strlen(LINK_HEAD)) == 0) {
            
            start = strchr(buf, '>') + 1;
            end = strrchr(buf, '<');
            memset(PUBLISH.link, 0, sizeof(PUBLISH.link));
            strncpy(PUBLISH.link, start, end - start); 
            //printf("%s\n", PUBLISH.link);

        }
        // read pubDate
        else if (strncmp(buf, PUBDATE_HEAD, strlen(PUBDATE_HEAD)) == 0) {
            
            start = strchr(buf, '>') + 1;
            end = strrchr(buf, '<');
            memset(PUBLISH.pubDate, 0, sizeof(PUBLISH.pubDate));
            strncpy(PUBLISH.pubDate, start, end - start); 

        }
        else if (strncmp(buf, ITEM_END, strlen(ITEM_END)) == 0) break;

    }

}
*/

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
            //printf("%s\n", PUBLISH.link);

        }
        // read pubDate
        else if (strstr(buf, PUBDATE_HEAD)) {

            start = strchr(buf, '>') + 1;
            end = strrchr(buf, '<');
            memset(PUBLISH.pubDate, 0, sizeof(PUBLISH.pubDate));
            strncpy(PUBLISH.pubDate, start, end - start); 

        }
        else if (strstr(buf, ENCLOSURE)) {

            start = strstr(buf, "url=") + 5;
            end = strchr(buf, '>') - 2;
            memset(PUBLISH.torrent, 0, sizeof(PUBLISH.torrent));
            strncpy(PUBLISH.torrent, start, end - start);

        }
        else if (strstr(buf, ITEM_END)) break;

    }
    //printf("%s\n%s\n%s\n", PUBLISH.title, PUBLISH.pubDate, PUBLISH.torrent);

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

    printf(MSG_TITLE"%s\n", PUBLISH.title);
    printf(MSG_PUBDATE"%s\n", PUBLISH.pubDate);
    printf(MSG_TORRENT"%s\n", PUBLISH.torrent); 
    memset(cmd, 0, sizeof(cmd));
    memset(msg, 0, sizeof(msg));
    memset(buf, 0, sizeof(buf));

    sprintf(msg, "\n[Title]： %s\n[PubDate]： %s\n[URL]： %s", PUBLISH.title, PUBLISH.pubDate, PUBLISH.link);
    sprintf(cmd, "curl -sX POST '%s'" \
                    " --header 'Content-Type: application/x-www-form-urlencoded'" \
                    " --header 'Authorization: Bearer %s'" \
                    " --data-urlencode 'Message=%s'", LINE_API, LINE_TOKEN, msg);

    fp_notify = popen(cmd, "r");
    if (fp_notify == NULL) exit(1);
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
    if (fp_torrent == NULL) exit(1);
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

    FILE * fp_http_req, * fp_filename;
    char * cmd, * start;
    char buf[BUF_SIZE], torrent_name[BUF_SIZE], code[4];
    
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
    if (fp_http_req == NULL) exit(1);
    fgets(buf, sizeof(buf), fp_http_req);
    memset(code, 0, sizeof(code));
    start = strrchr(buf, ':') + 1;
    strcpy(code, start);
    if (atoi(code) == HTTPCODE_OK) printf(MSG_NOTICE""MSG_ADDTASK""MSG_SUCCESS"\n");
    else                           printf(MSG_NOTICE""MSG_ADDTASK""MSG_FAIL"\n");
    pclose(fp_http_req);

    // wait until torrent file downloaded
    start = strrchr(PUBLISH.torrent, '/') + 1;
    strcpy(torrent_name, start);
    cmd = (char *)malloc(sizeof(char) * (len_filename_c + strlen(torrent_name) + strlen(DLDIR)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "transmission-show \"%s%s\" &> /dev/null;echo $?", DLDIR, torrent_name);
    while (1) {

        fp_filename = popen(cmd, "r");
        if (fp_filename == NULL) exit(1);
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
    cmd = (char *)malloc(sizeof(char) * (len_createfile + strlen(PUBLISH.filename) + strlen(DLDIR)));
    memset(cmd, 0, sizeof(cmd));
    sprintf(cmd, "touch '%s%s.upload'", DLDIR, PUBLISH.filename);
    system(cmd);
    free(cmd);

}

/*
 *  Check whether the publish is new.
 *  Input:  none
 *  Output: none
 */ 
bool checknew(void) {

    TIME T;
    time_t rawtime_tar;
    char * start, * end;
    char temp[BUF_SIZE];
    
    T.tm_isdst = 0;

    // parse mday
    start = strchr(PUBLISH.pubDate, ' ') + 1;
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
    
    rawtime_tar = mktime(&T);   // get target timestamp
    //printf("%ld %ld\n", rawtime_tar, LAST_TIME);

    return rawtime_tar > LAST_TIME;

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

        printf("First Run.\n");
        fp_time = fopen(TIMESTAMP_FILE, "w");
        if (fp_time == NULL) exit(1);
        fprintf(fp_time, "%ld\n", CUR_TIME);
        LAST_TIME = CUR_TIME;
        
    } else {

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
    if (fp_time == NULL) exit(1);
    fprintf(fp_time, "%ld\n", CUR_TIME);
    fclose(fp_time);

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