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

/*
* 'open_port()' - Open serial port 1.
*
* Returns the file descriptor on success or -1 on error.
*/

FILE *fp;

/* catch signal handler - write time if recording is on */
void catchSignal (int signum) {

        fflush(fp);
        fclose(fp);
        exit(0);
}

main (int argc, char** argv) {

	char* device_name = "/dev/ttyUSB0";
	int fd;
	char buffer[1];
	size_t nbytes;
	const char nl='\n';
	const char nlr='\r';
	int was_nl=0;
	int sql=0;
	struct timeval tmval;
	double time;
	ssize_t nn;
	char* logfile;
	double reftime;
	int c=0;

	while ((c = getopt (argc, argv, "d:l:r:")) != -1)
         switch (c)
           {
           case 'd':
             device_name = optarg;
             break;
           case 'l':
             logfile = optarg;
             break;
           case 'r':
             reftime = atof(optarg);
             break;
           case '?':
             if (optopt == 'd' || optopt == 'l' || optopt == 'r')
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

	fd = open_port(device_name);
	fp = fopen(logfile,"w");

        /* SIGINT handler */
        signal(SIGINT, catchSignal);
        signal(SIGTERM, catchSignal);

	nbytes=sizeof(buffer);
	while (1) {
		gettimeofday(&tmval, NULL);
		time=tmval.tv_sec + (tmval.tv_usec/1000000.0);
		nn=read(fd,buffer,nbytes);
		if (buffer[0] == nl || buffer[0] == nlr) {
			if (sql == 0 && was_nl == 0) {
				fprintf (fp, " %.2f %.2f ", reftime, time );
				sql=1;
				was_nl=1;
			}
			if (sql == 1 && was_nl == 0) {
				fprintf (fp, " %.2f\n", time );
				sql=0;
				was_nl=1;
			}
		} else 	{
			fprintf (fp, "%c", buffer[0] );
			was_nl=0;
		}
		fflush (fp);
	}
	close(fd);
	fclose(fp);
}

int open_port(char* device_name)
{
	int fd; /* File descriptor for the port */
	struct termios options;

	fd = open(device_name, O_RDWR | O_NOCTTY | O_NONBLOCK);
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

	cfsetispeed(&options, B9600);
	cfsetospeed(&options, B9600);

/*
* Set the new options for the port...
*/
	options.c_cflag |= (CLOCAL | CREAD);
	options.c_cflag &= ~PARENB;
	options.c_cflag &= ~CSTOPB;
	options.c_cflag &= ~CSIZE;
	options.c_cflag |= CS8;
	options.c_cflag &= ~CRTSCTS;
	options.c_lflag |= ICANON;
	options.c_lflag &= ~ECHO;
	options.c_lflag &= ~ECHOE;
	options.c_lflag &= ~ECHOK;
	options.c_lflag &= ~ECHONL;
	options.c_iflag &= ~(IXON | IXOFF | IXANY);
	options.c_oflag &= ~OPOST;
	options.c_oflag |= OCRNL;
	options.c_oflag &= ~ONLCR;
	tcsetattr(fd, TCSANOW, &options);
	}
	fcntl(fd, F_SETFL, 0);
	return (fd);
}
