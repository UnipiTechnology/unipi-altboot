
#include <features.h>
#include <ftw.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include <stdint.h>
#include <getopt.h>

int verbose = 0;
char output_template[256] = "cpio-list";

off_t  g_size = 0;
off_t  f_size;
int    chunk = 0;
off_t MAX_CHUNK_SIZE = 4000000000;
int output, outlist;

static void reopen_output(void)
{
    char output_name[256];
    if (chunk > 0)
        close(output);
    if (snprintf(output_name, sizeof(output_name), "%s.%03d", output_template, chunk) < 0) {
        perror("Cannot format filename");
        exit(EXIT_FAILURE);
    }
    output = open(output_name, O_CREAT | O_WRONLY, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
    if (output < 0) {
        perror("Create output file");
        exit(EXIT_FAILURE);
    }
    dprintf(outlist, "%s\n", output_name);
    chunk++;
}

static int
display_info(const char *fpath, const struct stat *sb,
             int tflag, struct FTW *ftwbuf)
{
    g_size += sb->st_size;
    if (tflag != FTW_D) {
        if (f_size + sb->st_size > MAX_CHUNK_SIZE) {
            reopen_output();
            if (verbose) printf("---- %d  %ld B  ----------------------------------------\n", chunk, f_size);
            f_size = sb->st_size;
        } else {
            f_size += sb->st_size;
        }
    }
    dprintf(output, "%s\n", fpath);

    if (verbose) printf("%-3s %7jd   %-40s\n",
        (tflag == FTW_D) ?   "d"   : (tflag == FTW_DNR) ? "dnr" :
        (tflag == FTW_DP) ?  "dp"  : (tflag == FTW_F) ?   "f" :
        (tflag == FTW_NS) ?  "ns"  : (tflag == FTW_SL) ?  "sl" :
        (tflag == FTW_SLN) ? "sln" : "???",
        (intmax_t) sb->st_size,
        fpath);
    return 0;           /* To tell nftw() to continue */
}


static struct option long_options[] = {
  {"output",  required_argument, 0, 'o'},
  {"chunk",  required_argument, 0, 'c'},
  {"symlink",  no_argument, 0, 's'},
  {"mount",  no_argument,   0, 'm'},
  {"verbose", no_argument,  0, 'v'},
  {0, 0, 0, 0}
};

static void print_usage(const char *progname)
{
  printf("usage: %s [-o output_files] [-c chunksize_in_MB] [-m] [-d] [-v]\n", progname);
  int i;
  for (i=0; ; i++) {
      if (long_options[i].name == NULL)  return;
      printf("  --%s%s\t %s\n", long_options[i].name,
                                long_options[i].has_arg?"=...":"",
                                "");
  }
}


int main(int argc, char *argv[])
{
    int flags = FTW_PHYS;
    int c;

    // Options
    while (1) {
        int option_index = 0;
        c = getopt_long(argc, argv, "vsmo:c:", long_options, &option_index);
        if (c == -1) {
            break;
        }
       
        switch (c) {
        case 'v':
            verbose++;
            break;
        case 's':
            flags &= ~FTW_PHYS;
            break;
        case 'm':
            flags |= FTW_MOUNT;
            break;
        case 'c':
            unsigned int x = atoi(optarg);
            if (x <= 0) {
                perror("Incorrect chunk size");
                exit(EXIT_FAILURE);
            }
            MAX_CHUNK_SIZE = x * 1024*1024;
            break;
        case 'o':
            strncpy(output_template, optarg, sizeof(output_template)-1);
            break;
        default:
            print_usage(argv[0]);
            exit(EXIT_FAILURE);
            break;
        }
    }
    outlist = open(output_template, O_CREAT | O_WRONLY, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
    if (outlist < 0) {
        perror("Create output file");
        exit(EXIT_FAILURE);
    }

    reopen_output();
    if (nftw((optind < argc) ? argv[optind] : ".", display_info, 20, flags)
            == -1) {
        perror("nftw");
        exit(EXIT_FAILURE);
    }
    close(output);
    close(outlist);
    if (verbose) printf("---- %d  %ld B  ----------------------------------------\n", chunk, f_size);
    if (verbose) printf("---- %ld B  ----------------------------------------\n", g_size);
    else
        printf("%ld\n", (g_size>>20)+1);
    exit(EXIT_SUCCESS);
}
