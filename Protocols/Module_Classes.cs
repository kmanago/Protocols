
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;

namespace PSProtocols
{
    public class Protocol
    {
        public Protocol () 
        { 
            this.Client_DisabledByDefault = null;
            this.Client_Enabled = null;
            this.Server_DisabledByDefault = null;
            this.Server_Enabled = null;
        }

        public System.Nullable<bool> Client_Enabled { get; set; }
        public System.Nullable<bool> Client_DisabledByDefault { get; set; }
        public System.Nullable<bool> Server_Enabled { get; set; }
        public System.Nullable<bool> Server_DisabledByDefault { get; set; }
    }
}