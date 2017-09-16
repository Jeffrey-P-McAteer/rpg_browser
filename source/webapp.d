import vibe.vibe;

/// Vibe.d application endpoints
class WebApp {
	
	void get() {
		getClient();
	}
	
	void getClient() {
		render!("client.dt");
	}
	
	void getServer() {
		render!("server.dt", dbconn); // todo work here
	}
	
	void postDelete_db() {
		redirect("server");
	}
}
