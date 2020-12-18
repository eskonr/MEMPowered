select 
pb.SerialNumber0 'Device Serial Number',
os.SerialNumber0 'Windows Product ID',
mdm.DeviceHardwareData0 'Hardware Hash',
'Group Tag'='SCCM'
from
v_GS_PC_BIOS pb
inner join v_R_System sys on sys.ResourceID=pb.ResourceID
inner join v_GS_OPERATING_SYSTEM os on os.ResourceID=pb.ResourceID
inner join v_GS_MDM_DEVDETAIL_EXT01 mdm on mdm.ResourceID=pb.ResourceID
where sys.Name0='Win10-001'
order by 1

