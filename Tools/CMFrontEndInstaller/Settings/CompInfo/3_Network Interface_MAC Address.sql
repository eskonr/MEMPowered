SELECT net.resourceid        AS 'Id', 
       CASE Charindex(',', net.ipaddress0) 
         WHEN 0 THEN net.ipaddress0 
         WHEN 1 THEN '' 
         ELSE LEFT(net.ipaddress0, Charindex(',', net.ipaddress0) - 1) 
       END                   AS 'IP Address', 
       net.macaddress0       AS 'MAC Address', 
       net.ipsubnet0         AS 'Subnet Mask', 
       net.defaultipgateway0 AS 'Gateway', 
       net.dnsdomain0        AS 'DNS Domain', 
       net.dhcpserver0       AS 'DHCP Server' 
FROM   dbo.v_gs_network_adapter_configuration net 
WHERE  net.ipenabled0 = 1 
       AND net.resourceid IN {0} 