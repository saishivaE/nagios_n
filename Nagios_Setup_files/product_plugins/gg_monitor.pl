#!/usr/bin/perl -w
#
# --> or /usr/bin/perl -w
#
# Accenture Enkitec Group
# Author: Gregory Thomas
# Send any bugs or enhancement requests to gthomas@enkitec.com

# Uncomment only when developing/debugging, do not need in production
use strict;
use warnings;
use constant CODE_VERSION => "v1.0.12";

# -------------------------------------
# Process Command Line Args
# -------------------------------------
# Test for command line arugment(s), exit if GGSHOME is not an ARGV
# Need GGS_HOME as commandline argv (each script run may use a different OGG home)

if (@ARGV < 1) {
  #print STDERR "Usage: $0 PATTERN [FILE...]\n";
  print STDERR "Usage: $0 <path to GGS_HOME> <path_to_param.ini> <path_to_scripts_dir>\n";
  print STDERR "<path_to_param.ini> <path_to_scripts_dir> are optional. Default values are GGS_HOME/dirprm/parm.ini and GGS_HOME/scripts\n";
  exit 1;
} else {
  unless ( -d $ARGV[0] ) 
  { 
    print "\nError: Directory $ARGV[0] does not exist!\n"; 
    print "\nError: GGS_HOME path must be passed to script at each invocation\n"; 
    exit 1; 
  }
}

# ---------------------
# Varaibles (Global)
# ---------------------

my $debug=2; 
my $loopcnt=1; 
my $ggshome=$ARGV[0];          # ARGV-0 - argument for path to $GGS_HOME
my $config=$ggshome . "/dirprm/parms.ini";   # properties file
if (@ARGV > 1){
    $config = $ARGV[1]
}

my $scriptsdir="$ggshome/scripts";
if (@ARGV > 2){
    $scriptsdir = $ARGV[2]
}

my $servername=qx{hostname};
my $INFOALL="$scriptsdir/INFOALL";
my $LOGFILE="$scriptsdir/gg_monitor.pl.log";
my $CSVFILE="$scriptsdir/csvdata.csv";


# Variables used in script processing
my $servername2=$ENV{'HOSTNAME'} || $ENV{'COMPUTERNAME'}; #
my %vhash = ();     # hash array to hold properties from parms.ini
my @errmsgs;        # array to hold all error/info messages
my @blackout;        # array to hold all error/info messages
my $blackoutstring;       # string value of all blackout values
my @infomsgs;       # array to hold informational only messages such as the run scorecard
my @infoall;       # array to hold informational from GGSCI
my @debuglog;       # array to hold log and debug messages for log file
my @csvdata;           # array to hold LAG/CHK data points for graphing
my @ggserrlog;           # array to hold ggserr.log records
my $process_error_flag = "N";    # flag to hold error status
my $print_dashboard = "N";     # flag to 
my @checks = ("lag_time","chk_time");  # internal controls for loop
my $cnt_extracts=0;      # total number of extracts seen in INFOALL file
my $cnt_replicats=0;     # total number of replicats seen in INFOALL file
my $error_status="";
my $loopflag=1;

# ---------------------------
# Functions
# ---------------------------
sub println 
{
    local $\ = "\n";
    print @_;
}
# -----------------------
sub debugln
{
   
   if ( $debug > 1 )
   {
    local $\ = "\n";
    #print "debug--> @_";
    #print LOGFILE "debug--> @_";
    push(@debuglog, "debug--> @_");
   }
} # end of debugln
# ----------------------------------

# ******************************************************************
# Start of Main
# ******************************************************************

# Loop
#for (my $i=0; $i <= $loopcnt; $i++) {
#while (1) 
while ($loopflag > 0) 
{
  system("echo \"\" > $LOGFILE");

  my @debuglog;
  @debuglog=();
  @debuglog=-1;

# 1) load parms.ini file into hash 
# 2) Run INFO ALL through ggsci, save output to array 
# 3) Process each line of INFOALL array (for process type)
#  3a) Many diferent types of checks included (all controlled by properties in parms.ini)
# 4) Print to errmsgs array for all error/status messages
# 5) Do notify function 

# Check platform type and change all paths to match
my $platform=$ENV{'SystemRoot'} || $ENV{'SHELL'};
debugln "host_platform_type-> $platform";

# Test for present and Read properties file (parms) into variables or a hash
# check if file exists and can be read
debugln "reading '$config' file to load all properties into vhash and set ENV for Oracle_Home/PATH";

open(IN, $config) || die "Cannot open $config for reading: $!";
while (<IN>)
{
   if ( not /\#/ || not /\=/ )
   {
     my $line = $_; 
     chomp $line;
     $line =~ s/"//g;
     debugln " ------------ new line --------------";
     #$o{$1}=$2 while m/(\S+)=(\S+)/g;
     my ($mykey, $mykeyval) = split(/=/,$line);
     #print "$1=$2\n";
     #my $mykey=$1;
     #my $mykeyval=$2;
     #${$1}="$2";
     $vhash{$mykey} = $mykeyval;  
     #$ENV{$mykey} = $mykeyval;
     #debugln " $$mykey-> $mykeyval = $mykeyval";
     debugln " mykey-> $mykey = mykeyval-> $mykeyval";
     # check if property is multi valued (has spaces), if so split into multiple variables
     if ( $mykeyval =~ /\s+/ || $mykeyval =~ /:/ )
     {
       debugln "  ** need to split (has space/:) mykeyval-> $mykeyval";
       if ($mykeyval =~ /:/)
       {
         debugln "  ** need to split because ':' in mykeyval"; 
         debugln "     mykey-> $mykey = mykeyval-> $mykeyval\n";
         my @marray = split(/\s+/, $mykeyval);
         #my @marray = split(/:/, $mykeyval);
         debugln join(", ", @marray);
         foreach my $element (@marray) 
         { 
           my ($keyv,$value) = split(/:/, $element);
           debugln "keyv -> $keyv value -> $value";
           my $newkey = $keyv . "_" . $mykey;
           #$ENV{$keyv}="$value"; 
           #$ENV{$newkey}="$value"; 
           $vhash{$keyv}="$value"; 
           $vhash{$newkey}="$value"; 
         }
       } else {
         debugln "  ** just spaces, so just multi-valued";
         debugln "     mykey-> $mykey = mykeyval-> $mykeyval\n";
         my @marray = split(/\s+/, $mykeyval);
         #$ENV{$mykey} = "n/a";
         #println join(", ", @marray);
         foreach (@marray) 
         { 
           my $newkey = $_ . "_" . $mykey;
           #$ENV{$_}="$mykey"; 
           #$ENV{$newkey}="$mykey"; 
           $vhash{$_}="$mykey"; 
           $vhash{$newkey}="$mykey"; 
         } # end of foreach myarray
      } # end of if mykeyval
    } # end of if
   } # end of if check 
} # end of while loop thru parms.ini

debugln "size of hash:  " . keys( %vhash ) . ".\n\n";

$debug = $vhash{'GGS_DEBUG'};
chomp $debug;

# Set ORACLE_HOME and PATH and LD_LIBRARY_PATH OR LIBPATH or SHLIB_PATH
# GGSCI needs access to ORacle Home libraries (XDK)

$ENV{'ORACLE_HOME'} = $vhash{'ORACLE_HOME'};
#$ENV{'LD_LIBRARY_PATH'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/lib:" . $ENV{'LD_LIBRARY_PATH'};
$ENV{'LD_LIBRARY_PATH'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/lib";
$ENV{'LIBPATH'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/lib";
$ENV{'SHLIBPATH'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/lib";
$ENV{'PATH'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/bin:" . "/bin:" . "/usr/bin:" . $ENV{'PATH'};
#$ENV{'PATH'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/bin"; 
#$ENV{'PERL5LIB'} = $ggshome . ":" . $vhash{'ORACLE_HOME'} . "/bin"; 

# ----------------------------------------------------
# Print out ENV variables (loaded from parms.ini processing)
# ----------------------------------------------------

debugln "list all %ENV environment variables created after processing 'parms.ini'";
foreach (sort keys %ENV) { debugln $_ . "=" . $ENV{$_}; }

debugln "\nlist all %vhash key/values created after processing 'parms.ini'";
foreach (sort keys %vhash) { debugln $_ . " = " . $vhash{$_}; }

# ----------------------------------------
# Run GGSCI "Info All" to produce status array
# ----------------------------------------

 $print_dashboard = $vhash{'print_dashboard'};
debugln "creating INFOALL file (running GGSCI command)--> $INFOALL";
push(@infoall, `echo 'info all' | $ggshome/ggsci`);
debugln "infoall array has --> @infoall";
 foreach (@infoall) 
 { 
   debugln "    infoall array element-> " . $_;
 }


# ----------------------------------------
# Process Line in INFOALL file (for type = BOTH, SOURCE, TARGET)
# ----------------------------------------

my $metrictype=$vhash{'metrictype'};
chomp($servername);

debugln "now process (read and loop through) INFOALL file --> $INFOALL";
#push(@errmsgs, "\n  INFO ");
push(@errmsgs, "\n      Server: $servername  Date: " . localtime);
#push(@errmsgs, "      Date: " . localtime);
push(@errmsgs, "      ----------------------------------\n");


# Add header to info dashboard
push(@infomsgs, "\n  ------------- Information Dashboard -------------"); 
push(@infomsgs, "   Server: $servername  Date: " . localtime() . "\n");
#push(@infomsgs, "   Date: " . localtime());
push(@infomsgs, "   Process List from Server\n");

# check for any wildcard values in 'blackout'

if ( $vhash{'blackout'} =~ /(\\*)/ )
{
    debugln " 'blackout' has wildcard characters---> $vhash{'blackout'}";
    # go through list and find wildcarded strings
    my @blackout_tmp = split(/\s+/,$vhash{'blackout'});
    my $size = $#blackout_tmp + 1;
    debugln " 'blackout_tmp' has wildcard strings (size)->" . $size;
    foreach (@blackout_tmp) 
    { 
      debugln "    blackout_tmp array value-> " . $_;
      #m{^\/\/(\*)+}
      #if ( $_ =! m{^\/\/(\*)+} )
      if ( $_ =~ m{(\*)+} )
      {
         debugln "      wildcard character found in array value-> " . $_;
         push (@blackout, $_);
      }
    } # end of foreach 
    $size = $#blackout + 1;
    debugln " 'blackout' has wildcard strings (size)->" . $size;
    foreach (@blackout) 
    { 
      debugln "    blackout array value-> " . $_;
    }
} # end of vhash check for blackout

 # ----------------------------------
 # try using a wildcard instead of checking for a hash key
 # greg - check process name against all blackout values
 # build regex string from all blackout values
 # ----------------------------------

 my @blackoutstringarray = split /\s+/, $vhash{'blackout'};

 debugln " now cycle through all elements in blackoutstringarray -> '@blackoutstringarray'";
 foreach (@blackoutstringarray) 
 { 
           debugln " blackoutstringarray element --> " . $_; 
           #$blackoutstring .= $_ . "|"; 
           $blackoutstring .= "^" . $_ . "|"; 
           #$blackoutstring .= "" . $_ . "|"; 
           debugln "                blackoutstring --> $blackoutstring";
 }
 chop ($blackoutstring);
 $blackoutstring =~ tr/\*/\+/;
 debugln "blackoutstring == '$blackoutstring'";


# ---------------------------------------------------------
# FOR LOOP THROUGH GGSCI output array, running all checks
# ---------------------------------------------------------

foreach (@infoall)
{

 # Only allow certain line types through for checks

 if ( $_ =~ /MANAGER|EXTRACT|REPLICAT/)
 {
    debugln "\n   ---------------- start for process --------------------";
    debugln "read--->" . $_;

    # Local variables to hold each line from INFOALL file
    my $ptype="n/a";
    my $pstatus="n/a";
    my $pname="n/a";
    my $pdmllag="n/a";
    my $pchklag="n/a";
    my $ptotaldmllag;
    my $ptotaldmllag_secs;
    my $ptotalchklag;
    my $ptotalchklag_secs;
    my $ptime=localtime;
    my $lag_hours;
    my $lag_mins;
    my $lag_secs;

    chomp;
    s/^\s+//; # remove leading whitespace
    s/\s+$//; # remove trailing whitespace
    
    # SKip any lines not MANAGER, REPLICAT or EXTRACT
    next unless length; # next rec unless anything left
    next if $_ =~ /(^\s*$)|(^\")|(^-)/;
    #next if $_ not =~ /(MANAGER|EXTRACT|REPLICAT)/;

    # Add (line from INFOALL) to @infomsgs array 
    push(@infomsgs, "    $_");

    # Manager (mgr) Checks - different from process checks...no lag or chk time parameters

    if ($_ =~ /MANAGER|JAGENT/)
    {
      debugln "process check for MGR";
      ($ptype, $pstatus) = split /\s+/, $_;
      debugln "ptype->" . $ptype . ", pname->" .  $pname. ", pstatus->" .  $pstatus . ", pdmllag->" .  $pdmllag . ", pchklag->" . $pchklag;
      # Check if process is ABENDED - by this point all process blackouts are excluded already
      #if ($pstatus =~ /RUNNING/)
      if ($pstatus =~ /STOPPED/)
      {
        $process_error_flag = "Y";
        my $msg = "$ptype process ($pname) has status '$pstatus'\n";
        debugln "pname-> $pname " . $msg;
        push(@errmsgs, "  ERROR " . $msg);
      } 
    } 

    # Process Checks
    if ($_ =~ /EXTRACT|REPLICAT/)
    {
      debugln "process check for EXTRACT/REPLICAT";
      ($ptype, $pstatus, $pname, $pdmllag, $pchklag) = split /\s+/, $_;
      debugln "ptype->" . $ptype . ", pname->" .  $pname. ", pstatus->" .  $pstatus . ", pdmllag->" .  $pdmllag . ", pchklag->" . $pchklag . ", process_error_flag->" . $process_error_flag;
      $cnt_extracts++ if ($ptype =~ /EXTRACT/);
      $cnt_replicats++ if ($ptype =~ /REPLICAT/);

      my $localvarname = $pname . "_blackout" || "null";
      debugln "localvarname -> $localvarname ";

      if ( exists $vhash{$localvarname} ) 
      {
 debugln "....... Skipping process pname-> $pname marked for blackout specifically by name--> $localvarname";
 next;
      } else {
        my $blackoutlist =  $vhash{'blackout'};

        # Now skip any processes that match a Blackout string list
        # greg now see if process name matches any string in blackout list (including wildcard strings)
        if ( $pname =~ /$blackoutstring/ )
        {
   debugln "....... skipping process pname-> $pname marked for blackout by regex to specific process name or wildcard string";
          debugln "  ***** skipping process check due to wildcard match **** $pname =~ m/$blackoutstring/";
          next;
        } # end if if for blackoutstring

      } # end of if for exists hash key


      # Convert lag/chk time to MINUTES or SECONDS
      # --------------------------------------------

      ($lag_hours,$lag_mins,$lag_secs) = split /:/, $pdmllag;
      $ptotaldmllag = ($lag_hours * 60) + $lag_mins;
      $ptotaldmllag_secs = ( ($lag_hours * 3600) + ($lag_mins * 60) ) + $lag_secs;
      debugln "  = ($lag_hours * 60) + $lag_mins";
      debugln "    ptotaldmllag-> $ptotaldmllag (lag_hours=$lag_hours lag_mins=$lag_mins lag_secs=$lag_secs) - minutes (pdmllag--> $pdmllag)";
      debugln "ptotaldmllag_sec-> $ptotaldmllag_secs (lag_hours=$lag_hours lag_mins=$lag_mins lag_secs=$lag_secs) - seconds";
      debugln " = ( ($lag_hours * 3600) + ($lag_mins * 60) ) + $lag_secs";

      $lag_hours=0;
      $lag_mins=0;
      $lag_secs=0;
     
      # Convert chk time to minutes and seconds

      ($lag_hours,$lag_mins,$lag_secs) = split /:/, $pchklag;
      $ptotalchklag = ($lag_hours * 60) + $lag_mins;
      $ptotalchklag_secs =( ($lag_hours * 3600) + ( $lag_mins * 60) + $lag_secs );
      debugln "  = ($lag_hours * 60) + $lag_mins";
      debugln "     ptotalchklag-> $ptotalchklag (lag_hours=$lag_hours lag_mins=$lag_mins lag_secs=$lag_secs) - minutes (pchklag -> $pchklag)";
      debugln "=(($lag_hours*3600)+($lag_mins*60)+$lag_secs)";
      debugln "ptotalchklag_secs-> $ptotalchklag_secs (lag_hours=$lag_hours lag_mins=$lag_mins lag_secs=$lag_secs) - seconds";

      # CSV Data Points
      # write data points (CSV lag data points ) - if needed
      # if seconds, write out in seconds,  if mininutes write out in minutes      

      debugln " CVS data point--> $ptime, $pname, $ptype, $pstatus, $ptotaldmllag, $ptotalchklag (metrictype-> $metrictype)";
      my $localtime_number = time();
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
      $year = $year + 1900;
      $mon = $mon + 1;

      # write csv data points
      # Change - write lagdelay in seconds or minutes
      # If metric is in seconds use "ptotalchklag_secs , if not use ptotalchklag

      my $metricmeasure=$metrictype;
      debugln " csvdata--> $ptime, $pname, $ptype, $pstatus, $ptotaldmllag, $ptotalchklag (metrictype-> $metrictype)";
      debugln "push(csvdata, $localtime_number,$year-$mon-$mday $hour:$min:$sec,$ptime,$pname,$ptype,$pstatus,$ptotaldmllag_secs,$ptotalchklag_secs,$metricmeasure";
      push(@csvdata, "$localtime_number,$year-$mon-$mday $hour:$min:$sec,$ptime,$pname,$ptype,$pstatus,$ptotaldmllag_secs,$ptotalchklag_secs,$metricmeasure");

     
      # Check if process is ABENDED - by this point all process blackouts are excluded already
      my $error_status = $vhash{'process_error_status'};
      debugln " error_status -> $error_status  (flag as error if process has this status)";
      debugln " ($pstatus =~ /$error_status/)";
      #if ($pstatus =~ /ABENDED/)
      if ($pstatus =~ /$error_status/)
      {
        $process_error_flag = "Y";
        my $msg = "$ptype process ($pname) has status '$pstatus'";
        debugln "pname-> $pname " . $msg;
        push(@errmsgs, "  ERROR " . $msg);
      } 

      # -------------------------------------------------
      # FOR LOOP through all processes in INFOALL file
      # run for loop to check DML and CHK lag for process
      # -------------------------------------------------

      foreach my $checktype (@checks)
      {    
        debugln " foreach loop.....     ------------> checktype-> $checktype ---------------";
        # Check if process Chk delay exceeds a custom or global metric from parms.ini
        my $global_chklag = $vhash{$checktype};
        my $tempvar = $pname . "_x" . $checktype;
        my $custom_chklag = $vhash{$tempvar} || 0;
        my $check_chklag = 0;
        my $type_metric = "";
        my $type_lag = "";
        chomp $global_chklag;
        chomp $custom_chklag;

        debugln " foreach loop.....global_chklag->$global_chklag custom_chklag->$custom_chklag check_chklag->$check_chklag process_error_flag->$process_error_flag";
        debugln " foreach loop.....checktype-> $checktype check_chklag-> $check_chklag type_metric->$type_metric type_lag->$type_lag";

        if ( $custom_chklag > 0 )
        {
          $check_chklag = $custom_chklag;
          $type_metric = "custom";
          debugln " setting check_chklag->$check_chklag custom_chklag->$custom_chklag type_metric ->$type_metric checktype-> $checktype";
        } else {
          $check_chklag = $global_chklag;
          $type_metric = "global";
          debugln " setting check_chklag->$check_chklag global_chklag->$global_chklag type_metric->$type_metric";
        } # end of if for custom check

        debugln " foreach loop.....global_chklag->$global_chklag custom_chklag->$custom_chklag check_chklag->$check_chklag process_error_flag->$process_error_flag";
        debugln " foreach loop.....checktype-> $checktype check_chklag-> $check_chklag type_metric->$type_metric type_lag->$type_lag";
        debugln " foreach loop.....global_chklag->$global_chklag custom_chklag-> $custom_chklag check_chklag->$check_chklag checktype->$checktype";

        # now do the comparison between the values
        # determine if checmking DML or CHK lag in this iteration

        debugln " foreach loop.....global_chklag-> $global_chklag custom_chklag -> $custom_chklag check_chklag ->$check_chklag checktype-> $checktype";
        my $currentlag = 0;
        my $check_word = "";
        my $timevalue = "";

        # set check values based on checktype (either dml or chk)

        if ( $checktype =~ /lag_time/ )
        {
           $timevalue = $pdmllag;
           if ( $vhash{'metrictype'} =~ /minutes/ )
           {
              debugln "  using metrictype-> minutes to test thresholds";
              # if using Minnutes
              $currentlag = $ptotaldmllag;
           } else {
              debugln "  using metrictype-> seconds to test thresholds";
             # if using seconds
             $currentlag = $ptotaldmllag_secs;
           }
           $check_word = "DML lag";
           $type_lag = $pname . "_blackoutlag";

        } else {

           $timevalue = $pchklag;
           if ( $vhash{'metrictype'} =~ /minutes/ )
           {
             # if using Minnutes
             $currentlag = $ptotalchklag;
           } else {
             # if using seconds
              $currentlag = $ptotalchklag_secs;
           }
           $check_word = "CHKP delay";
           $type_lag = $pname . "_blackoutchk";
        } # end of if for check_type (LAG or CHK)

        debugln " foreach loop.....global_chklag->$global_chklag custom_chklag->$custom_chklag check_chklag->$check_chklag currentlag-> $currentlag";
        debugln " foreach loop.....timevalue->$timevalue check_word->$check_word checktype->$checktype type_metric-> $type_metric ";

        if ( not exists $vhash{$type_lag} )
        { 
          my $msg = "";
          debugln " foreach loop.....global_chklag-> $global_chklag custom_chklag -> $custom_chklag check_chklag ->$check_chklag currentlag -> $currentlag";
          debugln " foreach loop.....now compare currentlag->$currentlag check_chklag->$check_chklag is $currentlag > $check_chklag  ";
          debugln " foreach loop..... check_word->$check_word ptotalchklag-> $ptotalchklag ";

          if ( $currentlag > $check_chklag )
          {
            debugln " foreach loop..... pname-> $pname variable NOT ($type_lag) found for exlcuding from lag type check type_lag-> $type_lag";
            debugln " foreach loop.....timevalue->$timevalue check_word->$check_word checktype->$checktype type_metric-> $type_metric check_word-> $check_word";
           
            $process_error_flag = "Y";
            #$msg = "$ptype process ($pname) with status ($pstatus) has exceeded $check_word ($type_metric): $ptotalchklag ($pchklag ) > $check_chklag)";
            $msg = "$ptype process ($pname) with status ($pstatus) has exceeded $check_word ($type_metric / in $vhash{'metrictype'}): $currentlag ($timevalue) > $check_chklag)";
            debugln " foreach loop..... pname-> $pname " . $msg . " process_error_flag -> " . $process_error_flag;
            push(@errmsgs, "  ERROR " . $msg . "\n");
            #push(@errmsgs, "    details: ptype->" . $ptype . ", pname->" .  $pname. ", pstatus->" .  $pstatus . ", pdmllag->" .  $pdmllag . ", pchklag->" . $pchklag . ", process_error_flag->" . $process_error_flag);
          } else {
            $msg = "$ptype process ($pname) with status ($pstatus) is ok $check_word ($type_metric): $currentlag ($timevalue ) > $check_chklag)";
            debugln " foreach loop..... pname-> $pname " . $msg;
          } # end of IF for currentlag > check_chklag 

        } else {

            debugln " foreach loop..... pname-> $pname variable found for exlcuding from lag type check type_lag-> $type_lag";
            debugln " foreach loop..... no check against $check_word since variable found exlcuding from $check_word check type_lag-> $type_lag";

        } # end of IF check for blackout variable existence   

        debugln " foreach loop.....pname-> $pname process_error_flag-> $process_error_flag type_metric -> $type_metric";
        debugln " foreach loop.....ptype->" . $ptype . ", pname->" .  $pname. ", pstatus->" .  $pstatus . ", pdmllag->" .  $pdmllag . ", pchklag->" . $pchklag . ", process_error_flag->" . $process_error_flag;

        debugln " foreach loop..... timevalue->$timevalue check_word->$check_word checktype->$checktype type_metric-> $type_metric";
        debugln " foreach loop..... ----------------- check_word->$check_word checktype->$checktype ------------------------";
      } # end of foreach loop thru two checks - dml and chk)

      debugln "  cnt_extracts -> $cnt_extracts , cnt_replicats -> $cnt_replicats";
      debugln "   ---------------- end for process (while loop) --------------------";

    } # end of IF for process checks
  } # end of IF for (MANAGER,EXTRACT,REPLICAT)
} # end of while thru INFOALL file


# Run process count checks against configured counts

debugln "alert_counts -> '$vhash{'alert_counts'}'";

 if ( $vhash{'alert_counts'} =~ /Y/ )
 {

   my $ggsmode=$vhash{'ggs_mode'};
   chomp $ggsmode;
   my $total_extract = $vhash{'extract_count'};
   my $total_replicat= $vhash{'replicat_count'};
   chomp $total_extract;
   chomp $total_replicat;

   debugln "checking process counts - ggsmode-> $ggsmode total_extract-> $total_extract  total_replicat-> $total_replicat";
   if ( $ggsmode =~ /SOURCE|BOTH/ )
   {
     debugln "checking process counts (for EXTRACT) ggsmode-> $ggsmode";
     if ( $cnt_extracts == $total_extract )
     {
      debugln "checking EXTRACT process counts MATCH : ggsmode-> $ggsmode total_extract-> $total_extract  cnt_extract-> $cnt_extracts";
     } else {
      $process_error_flag = "Y";
      my $msg = "Process counts for EXTRACT do not match configured state, running $cnt_extracts, configured for $total_extract processes"; 
      debugln "checking process counts DO NOT MATCH ggsmode-> $ggsmode total_extract-> $total_extract  ctn_extracts-> $cnt_extracts";
      push(@errmsgs, "WARNING " . $msg);
     } # end of if for count comparison

   } # end of if for SOURCE

   if ( $ggsmode =~ /TARGET|BOTH/ )
   {
    debugln "checking process counts (for REPLICAT) ggsmode-> $ggsmode";
    if ( $cnt_replicats == $total_replicat )
    {
      debugln "checking REPLICATprocess counts MATCH : ggsmode-> $ggsmode total_replicat-> $total_replicat  cnt_replicats-> $cnt_replicats";
    } else {
      $process_error_flag = "Y";
      my $msg = "Process counts for REPLICAT do not match configured state, running $cnt_replicats, configured for $total_replicat processes";
      debugln "checking process counts DO NOT MATCH : ggsmode-> $ggsmode total_replicat-> $total_replicat  total_replicat-> $total_replicat";
      push(@errmsgs, "WARNING " . $msg);
    } # end of if for count comparison

   } # end of if for SOURCE

 } # end of IF for alert_counts

# ------------------------------------------------------------
# Parse the "ggserr.log" looking for ERROR or WARNING messages, add to array and include in notifications
# ------------------------------------------------------------

  debugln " now check to see if 'ggserr.log' needs to be parsed parse_error_log -> $vhash{'parse_error_log'}";

  if ( $vhash{'parse_error_log'} =~ /Y/ )
  {
     my $count = 0;
     my $filesize = -s "$ggshome/ggserr.log";  # filesize used to control reaching the start of file while reading it backward
     my $offset = 0;     # skip two last characters: \n and ^Z in the end of file
     my @old_filesize;
     my $old_filesize = 0;
     my $previous_filesize = 0;
     my $current_filesize = 0;
     my $size_diff ;

     debugln "current size ggserr.log filesize-> '$filesize' bytes";
     # now test to see if .ggserr.log.size exists (get previous read position)
     if ( -e "$scriptsdir/.ggserr.log.size")
     {
        debugln "now test for .ggserr.log.size - EXISTS";
        open FILESIZE, "$scriptsdir/.ggserr.log.size" or die $!;
        @old_filesize = <FILESIZE>; 
        $current_filesize = $filesize;
        debugln "old_filesize -> '@old_filesize' current_filesize-> '$current_filesize'";
        close (FILESIZE);
        $previous_filesize = $old_filesize[0];
        $size_diff = $current_filesize - $previous_filesize;
        debugln "previous_filesize -> $previous_filesize size_diff-> $size_diff";
        if ( $previous_filesize > $current_filesize )
        {
          debugln "ggserr.log has been rotated previous_filesize-> $previous_filesize > old_filesize -> $old_filesize[0]";
          $previous_filesize = 0;
          $size_diff = $filesize;
        } else {
          debugln "ggserr.log has NOT been rotated previous_filesize-> $previous_filesize < old_filesize-> $old_filesize[0]";
        }
        debugln "previous_filesize-> $previous_filesize size_diff-> $size_diff current_filesize->$current_filesize";
     } else {
        debugln "now test for .ggserr.log.size - DOES NOT EXIST";
        # file does not exist, create with starting 0
        open FILESIZE, ">$scriptsdir/.ggserr.log.size" or die $!;
        print FILESIZE "0";
        $previous_filesize = 0;
        $size_diff = $filesize;
    }

     debugln "now trying a read from an offset (file is growing and only read new parts)";
     debugln "filesize -> $filesize";
     debugln "old_filesize -> $old_filesize";
     debugln "current_filesize -> $current_filesize";
     debugln "previous_filesize -> $previous_filesize";
     debugln "size_diff -> $size_diff";

     my $errmsgs_size = @errmsgs;
     #push(@ggserrlog, "\n   ------------ ggserr.log ERRORS ---------");

     my @filedata;
     my $filedata;

     open F, "$ggshome/ggserr.log" or die $!;  
     seek (F,$previous_filesize,0);  # Go to last area read
     read(F,$filedata,$size_diff);      #note the last 100 bytes get stored in $ab
     close(F);
     my $xc = 0;
     foreach (split(/\n/,$filedata)) 
     {
        if ( $_ =~ /ERROR/ )
        {
           $xc++; 
           debugln " ggserr.log #$xc-> $_";
           #push(@errmsgs, "$_");
           push(@ggserrlog, "$_");
        }
     }
     #push(@ggserrlog, "\n");

     # write out byte size of file read ( .ggserr.log.size )
     open FILESIZE, ">$scriptsdir/.ggserr.log.size" or die $!;
     print FILESIZE "$filesize";
     close (FILESIZE);

     if ( $xc > 1 ) 
     {
        debugln "xc -> $xc";
        debugln "errors listed in ggserr.log (line counted xc -> $xc";
     } else {
        debugln "xc -> $xc";
        debugln "no errors in ggserr.log ";
        push(@ggserrlog, "     ** no ERROR messages found\n");
     }
  } # end of if for parse_error_log check

# ------------------------------------------------------------------

# --------------------------------
# Notify and Output Section
# --------------------------------

 debugln "notify......      *****************************    ";
 debugln "notify......      Notify and Output Processing";
 debugln "notify......      *****************************    ";
 debugln "notify......      ";

 my $notifyflag = $vhash{'notifyflag'};
 chomp $notifyflag;
 my $outputmessage = $vhash{'outputmessage'};
 chomp $outputmessage;

 debugln "notify......notifyflag->$notifyflag outputmessage->$outputmessage process_error_flag->$process_error_flag";

 if ( $outputmessage =~ /Y/ ) 
 {
   debugln "notify......error messages from run, notifyflag->'$notifyflag' process_error_flag ->$process_error_flag";

   if ($process_error_flag =~ /Y/ )
   {
     debugln "notify......print out message array outputmessage->$outputmessage process_error_flag->$process_error_flag";
     
     foreach (@errmsgs) 
     { 
      println  $_;
      debugln  $_;
     }
     debugln "notify......" . @errmsgs if ( $debug > 1 );

     foreach (@infomsgs) 
     { 
      println  $_;
      debugln  $_;
     }

      if  ( $vhash{'parse_error_log'} =~ /Y/ )
      {
         my $ggserrlog_size = @ggserrlog;
         debugln "notify...... ggserrlog_size --> $ggserrlog_size";
         print "\n   ------------ ggserr.log ERRORS ---------\n";
         if ( $ggserrlog_size > 30 )
         {
           my $xc = 0;
           foreach (reverse(@ggserrlog))
           {
             $xc++;
             print $_ . "\n";
             last if ($xc > 10);
           }
         } else {
           foreach (@ggserrlog)
           {
             print $_ . "\n";
           }
           # greg99
           push(@ggserrlog,"\n");
         }
      } # end of if parse_error_log
     
   } else {
     debugln "notify......print out message array outputmessage->$outputmessage process_error_flag->$process_error_flag";
     println "\nSTATUS->OK\n";
     push(@errmsgs, "  INFO STATUS->OK\n");
     debugln @errmsgs if ( $debug > 1 );


   } # end of process_error_flag


   # ------------------------------------------------
   # Notify (customize for SMTP, SNMP or CLI)
   # ------------------------------------------------

   debugln " notifyflag-> $notifyflag  notifyonlyonerrors-> $vhash{'notifyonlyonerrors'} process_error_flag-> $process_error_flag";
   #if ( $notifyflag =~ /Y/ && $vhash{'notifyonlyonerrors'} =~ /Y/ && $process_error_flag =~ /Y/ ) 

   if ( $notifyflag =~ /Y/ )
   {
       debugln "notify...... no check process_error_flag->$process_error_flag or notifyonlyonerrors-> $vhash{'notifyonlyonerrors'}";

     if ( $process_error_flag =~ /Y/ || $vhash{'notifyonlyonerrors'} =~ /N/ )
     {
       debugln "notify......email will be sent process_error_flag->$process_error_flag or notifyonlyonerrors-> $vhash{'notifyonlyonerrors'}";
       debugln "notify......notifyflag->$notifyflag - building email notification due to process_error_flag->$process_error_flag";
       # Send email 
       my $to = $vhash{'mailuser'};
       my $from = $vhash{'fromuser'};
       my $subject = "OGG Monitoring Email from $vhash{'systemname'}";
       my $message = 'This is test email sent by Perl Script';
       #open(MAIL, "|/usr/sbin/sendmail -t");
       #open(MAIL, "|sendmail -t");
       debugln "open(MAIL, |/bin/mailx -s '$subject' $to )";
       open(MAIL, "|/bin/mailx -s '$subject' $to ");
       debugln "notify......Email details-> to-> $to from-> $from subject-> $subject";
       # Email Header
       print MAIL "To: $to\n";
       print MAIL "From: $from\n";
       print MAIL "Subject: $subject\n\n";
       # Email Body
       #print MAIL @errmsgs;
       foreach (@errmsgs) 
       {   
         print MAIL $_ . "\n";
       }

       if  ( $print_dashboard =~ /Y/ )
       {
         foreach (@infomsgs) 
         {   
           print MAIL $_ . "\n";
         }
       }

       if  ( $vhash{'parse_error_log'} =~ /Y/ )
       {
         my $ggserrlog_size = @ggserrlog;
         debugln "notify...... ggserrlog_size --> $ggserrlog_size";
         print MAIL "\n   ------------ ggserr.log ERRORS ---------\n";
         if ( $ggserrlog_size > 10 )
         {
           my $xc = 0;
           foreach (reverse(@ggserrlog)) 
           {   
             $xc++;
             print MAIL $_ . "\n";
             last if ($xc > 10);
           }
         } else {
           foreach (@ggserrlog) 
           {   
             print MAIL $_ . "\n";
           }
         }
       } # end of if for parse_error_log

       close(MAIL);
       debugln "notify......Email Sent Successfully - notifyflag->$notifyflag process_error_flag->$process_error_flag\n" ;

     } else {

      debugln "notify...... notification = No email sent process_error_flag->$process_error_flag or notifyonlyonerrors->$vhash{'notifyonlyonerrors'}";
     }

   } # end of if for notify

 } else { 
     debugln "notify......not outputing results - outputmessage->$outputmessage";
     debugln "notify......write out message outputmessage->$outputmessage";
     debugln "notify......" . @errmsgs;

 } # end of IF for outputmessage


# write data Points

 debugln "write out message outputmessage->$outputmessage";
 if ( $vhash{'writedatapoints'} =~ /Y/ )
 {
   debugln "write out message writedatapoints =~ /Y/ outputmessage->$outputmessage";
   open (CSVFILE, ">>$CSVFILE");
   foreach (@csvdata) 
   {   
     print CSVFILE "$_\n";
   }
   close (CSVFILE) or die "$!\n";
 }
  

  # --------------- debug log
  # now print out a debug log if configured
  if ( $debug > 0 )
  {
    # Open LOG file handle
    system("echo '' >  $LOGFILE");
    open (LOGFILE, ">",$LOGFILE);
    truncate LOGFILE,0;
    foreach (@debuglog)
    {
      print LOGFILE "$_\n";
    }
    close (LOGFILE) or die "$!\n";
    @debuglog = ();
    $#debuglog = -1;

  }

# Reset array and status variables for next run

 #$error_status = $vhash{'process_error_status'};

 @csvdata = ();
 @blackout = ();
 @debuglog = ();
 @infomsgs = ();
 @errmsgs = ();
 @ggserrlog = ();
 #$blackoutstring = "";
 @infomsgs = ();
 @infoall = ();
 @csvdata = ();

 $process_error_flag="N";
 $cnt_extracts=0;
 $cnt_replicats=0;


# Sleep for While loop
 my $sleep_interval = $vhash{'sleeptime'};

# Loop interval (check or exit)
 my $loop_interval = $vhash{'loopinterval'};
 debugln ("end of loop checking loopinterval--> $loop_interval");
 if ( $loop_interval == 0)
 {
    $loopflag=0;
    $sleep_interval=0;
 } else {
   #println "Finished loop --> #$loopcnt sleeping --> $sleep_interval";
   debugln ("Finished loop --> #$loopcnt sleeping --> $sleep_interval");
   sleep $sleep_interval;
   undef @debuglog;
   $loopcnt++;
 } 

} # end of endless while loop

# Set return status for shell execution (sometimes used by third-party tools that run the script)
if ( $process_error_flag =~ /Y/ )
{
   exit 1;
} else {
   exit 0;
}