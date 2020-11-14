SELECT sys.resourceid                          AS 'Id', 
       sys.name0                               AS 'System Name', 
       sys.user_domain0 + '\' + sys.user_name0 AS 'Main User', 
       ch.lastactivetime                       AS 'Last Seen (UTC)', 
       os.caption0                             AS 'OS Name', 
       os.csdversion0                          AS 'Service Pack', 
       CASE 
         WHEN comp.systemtype0 = 'x64-based PC' THEN 'x64' 
         ELSE 'x86' 
       END                                     AS 'Architecture', 
       os.installdate0                         AS 'Installation Date', 
       comp.domain0                            AS 'Domain Name', 
       sys.distinguished_name0                 AS 'Distinguished Name' 
FROM   dbo.v_r_system sys 
       INNER JOIN dbo.v_gs_operating_system os 
               ON sys.resourceid = os.resourceid 
       INNER JOIN dbo.v_gs_computer_system comp 
               ON sys.resourceid = comp.resourceid 
       INNER JOIN dbo.v_ch_clientsummary ch 
               ON sys.resourceid = ch.resourceid 
WHERE  sys.resourceid IN {0}