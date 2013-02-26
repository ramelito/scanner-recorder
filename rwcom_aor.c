#include <stdio.h>   /* Standard input/output definitions */
#include <ctype.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */

/*
* 'open_port()' - Open serial port 1.
*
* Returns the file descriptor on success or -1 on error.
*/

main (int argc, char** argv) {

	char* device_name = "/dev/ttyUSB0";
	char* command;
	char* cmdfile = "none";
	int fd;
	FILE *fp;
	char buffer[1024];
	char *bufptr;
	int nbytes;
	int r = 0;
	int timeout=250000;
	int c=0;

	command = malloc(4);
	snprintf(command, 4, "GLG\r");

	while ((c = getopt (argc, argv, "d:s:c:f:")) != -1)
         switch (c)
           {
           case 'd':
             device_name = optarg;
             break;
           case 's':
             timeout = atoi(optarg);
             break;
	   case 'c':
	     command = realloc(command, strlen(optarg)+2);
	     snprintf(command, strlen(optarg)+2, "%s%c", optarg, 0x0D);
	     /* printf("%d %s\n", strlen(optarg)+2, command); */
	     break;
	   case 'f':
	     cmdfile = optarg;
	     break;
           case '?':
             if (optopt == 'd' || optopt == 's' || optopt == 'c')
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

	if (cmdfile == "none" ) {
		exit(0);
	}

	fp = fopen (cmdfile, "r");

	if ( fp != NULL ) {
	      	char fline [ 255 ];
		fd = open_port(device_name);
	
	      	while ( fgets ( fline, sizeof fline, fp ) != NULL ) {
	     		command = realloc(command, strlen(fline)+2);
		        snprintf(command, strlen(fline)+2, "%s%c", fline, 0x0D);
			r=write(fd, command, strlen(command));
			usleep(timeout);

			/* read characters into our string buffer until we get a CR or NL */
			bufptr = buffer;
			while ((nbytes = read(fd, bufptr, buffer + sizeof(buffer) - bufptr - 1)) > 0)
			{
		  		bufptr += nbytes;
		  	//	if (bufptr[-1] == '\n' || bufptr[-1] == '\r')
	            	//	break;
			}
			
			*bufptr = '\0';
			fprintf (stdout, "%s", buffer);
			*buffer='\0';
			fflush(stdout);
      	      	}
		close(fd);
		free(command);
      		fclose ( fp );
   	}
   	else {
      		perror ( cmdfile ); /* why didn't the file open? */
   	}
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

	options.c_cflag &= ~PARENB;
	options.c_cflag &= ~CSTOPB;
	options.c_cflag &= ~CSIZE;
	options.c_cflag |= CS8;
	options.c_cflag &= ~CRTSCTS;
	tcsetattr(fd, TCSANOW, &options);
	}
/*	fcntl(fd, F_SETFL, FNDELAY);*/
	return (fd);
}
