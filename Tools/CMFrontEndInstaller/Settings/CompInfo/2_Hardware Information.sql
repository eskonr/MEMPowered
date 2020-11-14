IF Db_id('computerwarranty') IS NOT NULL 
  (SELECT DISTINCT comp.resourceid                    AS 'Id', 
          comp.manufacturer0                 AS 'Manufacturer', 
          comp.model0                        AS 'System Model', 
          enc.serialnumber0                  AS 'Serial Number', 
          CASE 
            WHEN wi.enddate IS NULL THEN 'Unknown' 
            ELSE 
              CASE 
                WHEN wi.enddate > Getdate() THEN 'Yes' 
                ELSE 'No' 
              END 
          END                                AS 'Under Warranty', 
          CONVERT(VARCHAR, wi.shipdate, 101) AS 'Ship Date', 
          CONVERT(VARCHAR, wi.enddate, 101)  AS 'Warranty End Date', 
          enc.smbiosassettag0                AS 'Asset Tag', 
          bios.smbiosbiosversion0            AS 'BIOS Version', 
          bios.releasedate0                  AS'BIOS Date', 
          cpu.name0                          AS 'CPU Name', 
          Cast(cpu.numberofcores0 AS VARCHAR(64)) 
          + ' (Physical) / ' 
          + Cast(cpu.numberoflogicalprocessors0 AS VARCHAR(64)) 
          + ' (Virtual)'                     AS 'CPU Numbers', 
          Cast(Round (Round(CONVERT (FLOAT, MEM.totalphysicalmemory0) / 1048576, 2), 2) AS VARCHAR(64))
          + ' GB'                            AS 'Total Memory' 
   FROM   dbo.v_gs_computer_system comp 
          INNER JOIN dbo.v_gs_system_enclosure enc 
                  ON comp.resourceid = enc.resourceid 
          INNER JOIN dbo.v_gs_pc_bios bios 
                  ON comp.resourceid = bios.resourceid 
          INNER JOIN dbo.v_gs_processor cpu 
                  ON comp.resourceid = cpu.resourceid 
          INNER JOIN dbo.v_gs_x86_pc_memory mem 
                  ON comp.resourceid = mem.resourceid 
          LEFT OUTER JOIN computerwarranty.dbo.computerwarrantyinfo wi 
                       ON comp.resourceid = wi.resourceid
   WHERE  comp.resourceid IN {0})
ELSE 
  (SELECT DISTINCT comp.resourceid         AS 'Id', 
          comp.manufacturer0      AS 'Manufacturer', 
          comp.model0             AS 'System Model', 
          enc.serialnumber0       AS 'Serial Number', 
          'Unknown'               AS 'Under Warranty', 
          ''                      AS 'Ship Date', 
          ''                      AS 'Warranty End Date', 
          enc.smbiosassettag0     AS 'Asset Tag', 
          bios.smbiosbiosversion0 AS 'BIOS Version', 
          bios.releasedate0       AS'BIOS Date', 
          cpu.name0               AS 'CPU Name', 
          Cast(cpu.numberofcores0 AS VARCHAR(64)) 
          + ' (Physical) / ' 
          + Cast(cpu.numberoflogicalprocessors0 AS VARCHAR(64)) 
          + ' (Virtual)'          AS 'CPU Numbers', 
          Cast(Round (Round(CONVERT (FLOAT, MEM.totalphysicalmemory0) / 1048576, 2), 2) AS VARCHAR(64))
          + ' GB'                 AS 'Total Memory' 
   FROM   dbo.v_gs_computer_system comp 
          INNER JOIN dbo.v_gs_system_enclosure enc 
                  ON comp.resourceid = enc.resourceid 
          INNER JOIN dbo.v_gs_pc_bios bios 
                  ON comp.resourceid = bios.resourceid 
          INNER JOIN dbo.v_gs_processor cpu 
                  ON comp.resourceid = cpu.resourceid 
          INNER JOIN dbo.v_gs_x86_pc_memory mem 
                  ON comp.resourceid = mem.resourceid
   WHERE  comp.resourceid IN {0})