SELECT LDISK.resourceid  AS 'Id', 
       LDISK.deviceid0   AS 'Drive Letter', 
       LDISK.volumename0 AS 'Volume Name', 
       Cast(Round(CONVERT (FLOAT, LDISK.freespace0)/1024, 2) AS VARCHAR(64)) 
       + ' GB'           AS 'Free Space', 
       Cast(LDISK.size0/1024 AS VARCHAR(64)) 
       + ' GB'           AS 'Total Space', 
       Cast(LDISK.freespace0*100/LDISK.size0 AS VARCHAR(64)) 
       + ' %'            AS 'Percent Free', 
       CASE 
         WHEN lock.protectionstatus0 >= 1 THEN 'Encrypted' 
         ELSE 'Unecrypted' 
       END               AS 'Bitlocker Status' 
FROM   v_gs_logical_disk LDISK 
       LEFT OUTER JOIN dbo.v_gs_encryptable_volume lock 
                    ON LDISK.resourceid = lock.resourceid 
                       AND lock.driveletter0 = LDISK.deviceid0 
WHERE  LDISK.drivetype0 = 3 
       AND LDISK.size0 > 0 
       AND LDISK.resourceid IN {0}