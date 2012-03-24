#include <stdio.h>   /* Standard input/output definitions */
#include <ctype.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */
#include <time.h>
#include <sys/time.h>
#include <signal.h>

/* default delay */
#define DELAY 0.8

/* global file pointer and record flag to write upon signal catch */
FILE *fp;
int rec=0;

/* catch signal handler - write time if recording is on */
void catchSignal (int signum) {
	pid_t my_pid;
	
	struct timeval tmval;
	double time;

	gettimeofday(&tmval, NULL);
	time=tmval.tv_sec + (tmval.tv_usec/1000000.0);

	if (rec==1) fprintf (fp, "%.2f\n", time ); 
	fflush(fp);
	fclose(fp);
	my_pid = getpid();
    	exit(0);
}

main (int argc, char** argv) {

	char* device_name = "/dev/ttyUSB0";
	char* glg = "GLG\r";
	char* sts = "STS\r";
	int fd;	/* file descriptor for serial port */
	FILE *fp2; /* file pointer for extensive logging */
	FILE *fp3; /* file pointer for pause file */
	char buffer[255]; /* buffer for data from serial port */
	char *dbuffer; /* copy of buffer for data */
	char *bufptr; /* var to handle getting data from serial port */
	int nbytes; /* var to handle getting data from serial port */
	int r=0;
	int timeout=250000; /* default timeout 250 ms */
	int c=0;
	int i=0;
	char *nl; /* var for removing \r and \n special characters from data */
	struct timeval tmval; /* timing var for get time function */
	double time; /* vars to write in logfile */
	double timer0; /* timer var for record  delay */
	double timer=0.0; /* timer var for record delay */
	char *token; /* token var to split data received from serial port based on comma */
	int n; /* index var for tokens */
	int sql; /* squelch flag */
	char *freq; /* freq line got from serial port */
	char *freq2="empty"; /* var for storing previous value of freq */
	char* logfile = "/tmp/glgsts.log"; /* log file var */
	char* logdir = "no"; /* log dir to store extensive logging */
	char* pausefile = "/tmp/pausefile"; /* pause file */
	char idfile[1024]; /* id file which is assoc with start time of transmission */
	char id[17]; /* converted to char double time var */
	char* oldid="1.0";
	double reftime; /* referenced time to store in logfile */
	double delay=DELAY; /* delay var for record delay */
	int pflag=48; /* pause flag */
	int fp2open=0;

	while ((c = getopt (argc, argv, "d:s:l:r:i:t:p:")) != -1)
         switch (c)
           {
           case 'd':
             device_name = optarg;
             break;
           case 's':
             timeout = atoi(optarg);
             break;
           case 'l':
             logfile = optarg;
             break;
           case 'r':
             reftime = atof(optarg);
             break;
           case 'i':
             logdir = optarg;
             break;
           case 't':
             delay = atof(optarg);
             break;
           case 'p':
             pausefile = optarg;
             break;
           case '?':
             if (optopt == 'd' || optopt == 's' || optopt == 'l' || optopt == 'r' || optopt == 'i' || optopt == 't' || optopt == 'p')
               fprintf (stderr, "Option -%c requires an argument.\n", optopt);
             else if (isprint (optopt))
               fprintf (stderr, "Unknown option `-%c'.\n", optopt);
             else
               fprintf (stderr,
                        "Unknown option character `\\x%x'.\n",
                        optopt);
             return 1;
           default:
             abort ();
           }

	/* opening serial port and logfile */
	fd = open_port(device_name);
	fp = fopen(logfile,"w");

	/* SIGINT handler */
	signal(SIGINT, catchSignal);
	signal(SIGTERM, catchSignal);

	while (1) {	

		fp3 = fopen(pausefile, "r");
		pflag=fgetc(fp3);
		fclose(fp3);

		if ( pflag == 49 && rec == 1 ) {
			gettimeofday(&tmval, NULL);
			time=tmval.tv_sec + (tmval.tv_usec/1000000.0);

			fprintf (fp, "%.2f\n", time ); 
			fflush(fp);

			rec=0;
		}

		if ( pflag == 49 ) {

			usleep(timeout);
			continue;
		}
		
		/* odd step - glg command, even - sts command */
		if ( i % 2 == 0 ) {
			r=write(fd, glg, 4);
		} else {
			r=write(fd, sts, 4);
		}

		/* wait for answer */
		usleep(timeout);

		/* read characters into our string buffer until we get a CR or NL */
		bufptr = buffer;
		while ((nbytes = read(fd, bufptr, buffer + sizeof(buffer) - bufptr - 1)) > 0)
		{
		  bufptr += nbytes;
		  if (bufptr[-1] == '\n' || bufptr[-1] == '\r')
	            break;
		}

		*bufptr = '\0';

		/* remove \r and \n on serial port answer */
		nl = strrchr(buffer, '\r');
		if (nl) *nl = '\0';
		nl = strrchr(buffer, '\n');
		if (nl) *nl = '\0';
		
		/* if recording is on and sts command output data to file with start time id */
		if (rec==1 && i % 2 == 1 && strcmp(logdir,"no") !=0 ) {
			if ( strcmp(id,oldid) != 0 ) {
				if (fp2open == 1 ) fclose(fp2);
				*idfile='\0';
				strcat(idfile,logdir);
				strcat(idfile,"/");
				strcat(idfile,id);
				fp2 = fopen(idfile,"a+");
				fp2open=1;
			}
			fprintf(fp2, "%s\n", buffer);
			oldid=strdup(id);
		}

		if ( rec==0 && i % 2 == 1 && strcmp(logdir,"no") !=0 ) {
			if (fp2open == 1) {
				fclose(fp2);
				fp2open=0;
			}
		}

		if ( i % 2 == 0 ) {

			/* parsing glg answer from serial port, we need squelch and freq data */	
			dbuffer=strdup(buffer);
			n=0;
			sql=0;
			while (token != NULL && n < 13) {
				token=strsep(&dbuffer, ",");
				if (n==1 && token != '\0' ) freq=strdup(token);
				if (n==8) sql=atoi(token);
				n++;
			} 

			/* squelch is closed */
			if (sql==0) {
				/* but recording is on */
				if (rec==1) {
					gettimeofday(&tmval, NULL);
					/* lets start timer to wait */
					if (timer==0.0) {
						timer=tmval.tv_sec + (tmval.tv_usec/1000000.0);
					}
					timer0=tmval.tv_sec + (tmval.tv_usec/1000000.0);
					/* stop recording if timer is expired */
					if ( timer0-timer > delay ) {
						rec=0;
						freq="nosignal";
						timer=0.0;
						time=tmval.tv_sec + (tmval.tv_usec/1000000.0);
						fprintf (fp, "%.2f\n", time ); 
						fflush(fp);
					}
				}
				/* if rec is off continue cycle */
				continue;
			}			
	
			/* get current time */
			gettimeofday(&tmval, NULL);
			time=tmval.tv_sec + (tmval.tv_usec/1000000.0);

			/* if freq is empty there is no signla? */
			if (*freq == '\0') {
				if (rec==0) {
					freq="nosignal";
				} else {
					freq=strdup(freq2);
				}
			}

			/* squelch is opened */
			if (sql==1) {
				/* switched transmission when it is delay initiated */
				if (strcmp(freq,freq2) !=0 && rec==1 || strcmp(freq,freq2) !=0 && timer > 0.0 ) {
					rec=0;
					fprintf (fp, "%.2f\n", time ); 
					fflush(fp);
				}
				/* new transmission ever */
				if (strcmp(freq,freq2) !=0 || rec==0 ) {
					fprintf (fp, "%s,%.2f,%.2f,", buffer, reftime, time);
					fflush(fp);
					rec=1;
					sprintf(id, "%.2f", time);
				}
				timer=0.0;
			}
			/* save previous transmission state */
			freq2=strdup(freq);
		}

		*buffer='\0';
		i++;
	}

	close(fd);
	fclose(fp);
	free(dbuffer);
	free(freq);
	free(freq2);
}

int open_port(char* device_name)
{
	int fd; /* File descriptor for the port */
	struct termios options;

	fd = open(device_name, O_RDWR | O_NOCTTY | O_NDELAY);
	if (fd == -1)
	{
/*
* Could not open the port.
*/

	perror("open_port");
	} else {

/*
* Get the current options for the port...
*/

	tcgetattr(fd, &options);

/*
* Set the baud rates to 115200...
*/

	cfsetispeed(&options, B115200);
	cfsetospeed(&options, B115200);

/*
* Set the new options for the port...
*/
	options.c_cflag |= (CLOCAL | CREAD);
	options.c_cflag &= ~PARENB;
	options.c_cflag &= ~CSTOPB;
	options.c_cflag &= ~CSIZE;
	options.c_cflag |= CS8;
	options.c_cflag &= ~CRTSCTS;
	options.c_lflag &= ~ICANON;
	options.c_lflag &= ~ECHO;
	options.c_lflag &= ~ECHOE;
	options.c_lflag &= ~ECHOK;
	options.c_lflag &= ~ECHONL;
	options.c_iflag &= ~(IXON | IXOFF | IXANY);
	options.c_oflag &= ~OPOST;
	options.c_oflag |= OCRNL;
	options.c_oflag &= ~ONLCR;
	tcsetattr(fd, TCSAFLUSH, &options);
	}
	return (fd);
}

