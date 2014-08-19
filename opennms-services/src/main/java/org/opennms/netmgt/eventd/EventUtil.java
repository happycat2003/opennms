/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2012-2014 The OpenNMS Group, Inc.
 * OpenNMS(R) is Copyright (C) 1999-2014 The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is a registered trademark of The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * OpenNMS(R) is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with OpenNMS(R).  If not, see:
 *      http://www.gnu.org/licenses/
 *
 * For more information contact:
 *     OpenNMS(R) Licensing <license@opennms.org>
 *     http://www.opennms.org/
 *     http://www.opennms.com/
 *******************************************************************************/

package org.opennms.netmgt.eventd;

import java.sql.SQLException;
import java.util.Map;
import org.opennms.netmgt.xml.event.Event;

/**
 * EventUtil is used primarily for the event parm expansion - has methods used
 * by all the event components to send in the event and the element to expanded
 * and have the 'expanded' value sent back
 *
 * @author <A HREF="mailto:sowmya@opennms.org">Sowmya Kumaraswamy </A>
 * @author <A HREF="mailto:weave@oculan.com">Brain Weaver </A>
 * @author <A HREF="http://www.opennms.org/">OpenNMS </A>
 */
public abstract interface EventUtil {

	/**
	 * Retrieve nodeLabel from the node table of the database given a particular
	 * nodeId.
	 * 
	 * @deprecated Replace with standard DAO calls instead of using JDBC
	 * @param nodeId
	 *            Node identifier
	 * 
	 * @return nodeLabel Retreived nodeLabel
	 * 
	 * @throws SQLException
	 *             if database error encountered
	 */
	String getNodeLabel(long nodeId) throws SQLException;

	/**
	 * Retrieve ifAlias from the snmpinterface table of the database given a particular
	 * nodeId and ipAddr.
	 *
     * @deprecated Replace with standard DAO calls instead of using JDBC
	 * @param nodeId
	 *            Node identifier
	 * @param ipAddr
	 *            Interface IP address
	 *
	 * @return ifAlias Retreived ifAlias
	 *
	 * @throws SQLException
	 *             if database error encountered
	 */
	String getIfAlias(long nodeId, String ipaddr) throws SQLException;

    /**
     * Helper method.
     * 
     * @deprecated Replace with standard DAO calls instead of using JDBC
     * @param parm
     * @param event
     * @return The value of an asset field based on the nodeid of the event 
     */
    String getAssetFieldValue(String parm, long nodeId);

	String expandParms(String string, Event event);
	
	String expandParms(String inp, Event event, Map<String, Map<String, String>> decode);

	String escape(String string, char c);

	String getNamedParmValue(String string, Event event);

	void expandMapValues(Map<String, String> parmMap, Event event);

	String getValueOfParm(String tagUei, Event m_svcLostEvent);	

}