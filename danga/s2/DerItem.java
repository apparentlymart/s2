package danga.s2;

public class DerItem
{
    public int dist;
    public NodeClass nc;
    public NodeFunction nf;

    public DerItem (NodeClass nc, int dist) {
	this.dist = dist;
	this.nc = nc;
    }

    public DerItem (NodeFunction nf, int dist) {
	this.dist = dist;
	this.nf = nf;
    }

    public String toString () {
	return (nc != null ? nc.toString() : nf.toString()) + "-@" + dist;
    }
}
