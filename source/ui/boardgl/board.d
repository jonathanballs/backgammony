module ui.boardgl.board;

import gdk.Color;
import gdk.GLContext;
import gtk.GLArea;
import gtk.Widget;

import derelict.opengl;

class BoardGL : GLArea
{
    this() {

        setAutoRender(true);
		addOnRender(&render);
		addOnRealize(&realize);
		addOnUnrealize(&unrealize);
		showAll();
	}
	
	bool render (GLContext c, GLArea a) {
		makeCurrent();

        glClearColor(0.3, 0.3, 0.3, 1);
		return true;
	}

  void realize(Widget) {
    makeCurrent();
    DerelictGL3.reload();
  }

  void unrealize(Widget) {
    makeCurrent();
  }
}
