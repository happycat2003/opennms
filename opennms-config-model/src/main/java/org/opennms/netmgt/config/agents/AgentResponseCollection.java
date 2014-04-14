package org.opennms.netmgt.config.agents;

import java.util.Collection;
import java.util.List;

import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;

import org.opennms.netmgt.model.RestResponseCollection;

@XmlRootElement(name="agents")
public class AgentResponseCollection extends RestResponseCollection<AgentResponse> {
    private static final long serialVersionUID = 1L;

    public AgentResponseCollection() { super(); }
    public AgentResponseCollection(final Collection<? extends AgentResponse> responses) {
        super(responses);
    }

    @XmlElement(name="agent")
    public List<AgentResponse> getObjects() {
        return super.getObjects();
    }
}