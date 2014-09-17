![](http://i.imgur.com/FzS2zfM.png)

# Major League Hacking Calendar

This essentially scrapes events on [mlh.io](http://mlh.io) and converts the data directly into a `.ical` format. It detects your location to show only local events (UK subscribers won't receive information on US events) but entering `cal.mlh.io/:region` (i.e `us`) can override this.

There's two ways you can interact with MLH Calendar:
- Enter `cal.mlh.io` on your browser to view all events and add individually.
- Subscribe to `cal.mlh.io` to automatically have the events on your list.

## View upcoming hackathons
Simply type in `http://cal.mlh.io` on your iPhone and this should appear:

![](http://i.imgur.com/dmKtrW0.png)


## Subscribe to upcoming hackathons (iOS)

Follow these steps on your iOS device:

- Go to **Settings**
- Go to **Mail, Contacts, Calendars**
- Click **Add Account**
- Click on Other
- Click on **Add Subscribed Calendar**
- Enter as Server: `http://cal.mlh.io`
- Save

You should now automatically see MLH events appear in your iPhone's native calendar application. If you use a different calendar, it should have it's own "subscribe to a calendar" feature which you should just enter `http://cal.mlh.io` for.


## Subscribe to upcoming hackathons (Mac)

Follow these steps on your Mac:

- Go to Calendar.app
- Click on **File**
- Click on **New Calendar Subscription**
- Enter Calendar URL: `http://cal.mlh.io`
- Set **Auto-refresh** to Every week
- Save!

![](http://i.imgur.com/yDgeoGB.png)
![](http://i.imgur.com/j4x4rKv.png)

-----

## Fork it, hack it and improve it!
We've opened sourced the guts behind the MLH Calendar, which is built using Ruby/Sinatra. If you already have Ruby and Git installed, it's as simple as:

```
$ git clone https://github.com/mlh/cal.mlh.io.git
$ cd cal.mlh.io
$ bundle install
$ rackup
```

Your contributions would be very welcomed.