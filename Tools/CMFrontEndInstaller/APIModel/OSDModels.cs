using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Web;

namespace FrontendOSDDataLib
{
    /// <summary>
    /// Computer object for CMFrontend OSD transactions.
    /// </summary>
    public class OSDComputer
    {
        /// <summary>
        /// The computer name of the system
        /// </summary>
        [Required]
        public string ComputerName { get; set; }

        /// <summary>
        /// The SMBIOS ID of the computer
        /// </summary>
        [Required]
        public Guid SMBIOS { get; set; }

        /// <summary>
        /// The SCCM ResourceID for the computer
        /// </summary>
        [Required]
        public int? ResourceID { get; set; }

        /// <summary>
        /// Used to determine if one OSDComputer object is equal to another.
        /// </summary>
        /// <param name="obj">The object to compare against.</param>
        public bool IsEqual(object obj)
        {
            if (obj == null || GetType() != obj.GetType())
                return false;

            var computer = (OSDComputer)obj;

            return (ComputerName == computer.ComputerName) && (SMBIOS == computer.SMBIOS) && (ResourceID == computer.ResourceID);
        }
    }

    /// <summary>
    /// The request object sent by the end-user for dealings with Computer objects via OSD API.
    /// </summary>
    public class OSDComputerRequest
    {
        /// <summary>
        /// The computer name of the system.
        /// </summary>
        [Required]
        public string ComputerName { get; set; }

        /// <summary>
        /// The SMBIOS ID of the system
        /// </summary>
        [Required]
        public Guid SMBIOS { get; set; }

        /// <summary>
        /// The MAC address of the system.
        /// </summary>
        public string MACAddress { get; set; }
    }

    /// <summary>
    /// The request object sent by the end user to create a new computer object in SCCM.
    /// </summary>
    public class OSDCreateComputerRequest
    {
        /// <summary>
        /// The computer request object that specifies the data for the system that is to be created. <see cref="OSDComputerRequest"/> 
        /// </summary>
        [Required]
        public OSDComputerRequest Computer { get; set; }

        /// <summary>
        /// If true, anyexisting records will be overritten. 
        /// </summary>
        public bool RemoveExistingRecord { get; set; }
    }

    /// <summary>
    /// The request object sent by the end user to get data back about a system from its SMBIOS ID.
    /// For example, if you want to know if a system is in SCCM without needing to know the computer name.
    /// </summary>
    public class OSDGetComputerRequest
    {
        /// <summary>
        /// The SMBIOS ID of the system.
        /// </summary>
        [Required]
        public Guid SMBIOS { get; set; }

        /// <summary>
        /// The MACAddress of the system.
        /// </summary>
        public string MACAddress { get; set; }
    }

    /// <summary>
    /// The request object sent by the end user to get data back about a system from its computer name.
    /// For example, if you want to know if a system already exists in SCCM based on a computer name.
    /// </summary>
    public class OSDComputerByNameRequest
    {
        /// <summary>
        /// The Computer name of the system.
        /// </summary>
        [Required]
        public string ComputerName { get; set; }
    }

    /// <summary>
    /// Contains the Name and DN of an Active Directory OU.
    /// </summary>
    public class OSDActiveDirectoryOU
    {
        /// <summary>
        /// The name of the AD OU
        /// </summary>
        public string Name { get; set; }
        
        /// <summary>
        /// The Distingished Name of the AD OU.
        /// </summary>
        [Required]
        public string DistinguishedName { get; set; }
    }

    /// <summary>
    /// Represents a Task Sequence deployment that is active in SCCM.
    /// </summary>
    public class OSDTSAdvertisement
    {
        /// <summary>
        /// The name of the Task Sequence.
        /// </summary>
        public string Name { get; set; }

        /// <summary>
        /// The ID of the deployment.
        /// </summary>
        public string AdvertisementID { get; set; }

        /// <summary>
        /// The Collection ID the deployment is targeting.
        /// </summary>
        public string CollectionID { get; set; }

        /// <summary>
        /// The category of the Task Sequence.
        /// </summary>
        public string Category { get; set; }

        /// <summary>
        /// Override of the ToString function.
        /// </summary>
        /// <returns>The name of the task sequence.</returns>
        public override string ToString()
        {
            return Name;
        }
    }

    /// <summary>
    /// The request object sent by the end user to request a list of task sequences available for deployment.
    /// </summary>
    public class OSDTSAdvertismentRequest
    {
        /// <summary>
        /// Specifies if you want to include development task sequenes.
        /// </summary>
        [Required]
        public bool Development { get; set; }

        /// <summary>
        /// The text to search for in the category field of the task sequence. If null, all task sequences are returned.
        /// </summary>
        public string CategoryFilter { get; set; }

        public OSDTSAdvertismentRequest()
        {
            Development = false;
        }
    }

    /// <summary>
    /// Represents basic information about a SCCM Collection.
    /// </summary>
    public class OSDCollection
    {
        /// <summary>
        /// The Collection name.
        /// </summary>
        public string Name { get; set; }
        /// <summary>
        /// The Collection ID.
        /// </summary>
        [Required]
        public string ID { get; set; }
    }

    /// <summary>
    /// The request object sent by the end user to add a computer to a SCCM collection.
    /// </summary>
    public class OSDCollectionMembershipRequest
    {
        /// <summary>
        /// The Collection to add the computer object to.
        /// </summary>
        [Required]
        public OSDCollection Collection { get; set; }
        /// <summary>
        /// The computer object to add to the collection.
        /// </summary>
        [Required]
        public OSDComputer Computer { get; set; }
    }
	
	public class OSDUserLookupRequest
    {
        public string UserName { get; set; }
    }
    public class OSDUserLookup
    {
        public string UserName { get; set; }
        public string DisplayName { get; set; }
    }
}