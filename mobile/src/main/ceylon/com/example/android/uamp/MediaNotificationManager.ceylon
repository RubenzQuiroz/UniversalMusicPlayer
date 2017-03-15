import android.app {
    Notification,
    PendingIntent,
    NotificationManager
}
import android.content {
    BroadcastReceiver,
    Context,
    Intent,
    IntentFilter
}
import android.graphics {
    Bitmap,
    BitmapFactory,
    Color
}
import android.os {
    RemoteException
}
import android.support.v4.media {
    MediaMetadataCompat,
    MediaDescriptionCompat
}
import android.support.v4.media.session {
    PlaybackStateCompat,
    MediaSessionCompat,
    MediaControllerCompat
}
import android.support.v7.app {
    NotificationCompat
}

import com.example.android.uamp.ui {
    MusicPlayerActivity
}
import com.example.android.uamp.utils {
    themeColor
}

import java.lang {
    IllegalArgumentException,
    System
}
import java.util {
    Objects
}

shared class MediaNotificationManager {

    static value notificationId = 412;
    static value requestCode = 100;

    static value actionPause = "com.example.android.uamp.pause";
    static value actionPlay = "com.example.android.uamp.play";
    static value actionPrev = "com.example.android.uamp.prev";
    static value actionNext = "com.example.android.uamp.next";
    static value actionStopCasting = "com.example.android.uamp.stop_cast";

    MusicService service;
    shared new (MusicService service) {
        this.service = service;
    }

//    value tag = LogHelper.makeLogTag(`MediaNotificationManager`);

    value notificationColor = themeColor(service, R.Attr.colorPrimary, Color.dkgray);
    value notificationManager = service.getSystemService(`NotificationManager`);
    notificationManager.cancelAll();

    value pkg = service.packageName;

    value pauseIntent = PendingIntent.getBroadcast(service, requestCode,
        Intent(actionPause).setPackage(pkg), PendingIntent.flagCancelCurrent);

    value playIntent = PendingIntent.getBroadcast(service, requestCode,
        Intent(actionPlay).setPackage(pkg), PendingIntent.flagCancelCurrent);

    value previousIntent = PendingIntent.getBroadcast(service, requestCode,
        Intent(actionPrev).setPackage(pkg), PendingIntent.flagCancelCurrent);

    value nextIntent = PendingIntent.getBroadcast(service, requestCode,
        Intent(actionNext).setPackage(pkg), PendingIntent.flagCancelCurrent);

    value stopCastIntent = PendingIntent.getBroadcast(service, requestCode,
        Intent(actionStopCasting).setPackage(pkg), PendingIntent.flagCancelCurrent);

    variable MediaSessionCompat.Token? sessionToken = null;
    variable MediaControllerCompat? controller = null;
    variable MediaControllerCompat.TransportControls? transportControls = null;
    variable MediaMetadataCompat? metadata = null;
    variable PlaybackStateCompat? playbackState = null;

    variable Boolean started = false;

    void addPlayPauseAction(NotificationCompat.Builder builder) {
//        LogHelper.d(tag, "updatePlayPauseAction");

        String label;
        Integer icon;
        PendingIntent intent;
        if (exists playback = playbackState,
            playback.state == PlaybackStateCompat.statePlaying) {
            label = service.getString(R.String.label_pause);
            icon = R.Drawable.uamp_ic_pause_white_24dp;
            intent = pauseIntent;
        } else {
            label = service.getString(R.String.label_play);
            icon = R.Drawable.uamp_ic_play_arrow_white_24dp;
            intent = playIntent;
        }

        builder.addAction(icon, label, intent);
    }

    function createContentIntent(MediaDescriptionCompat? description) {
        value openUI = Intent(service, `MusicPlayerActivity`);
        openUI.setFlags(Intent.flagActivitySingleTop);
        openUI.putExtra(MusicPlayerActivity.extraStartFullscreen, true);
        if (exists description) {
            openUI.putExtra(MusicPlayerActivity.extraCurrentMediaDescription, description);
        }
        return PendingIntent.getActivity(service, requestCode, openUI, PendingIntent.flagCancelCurrent);
    }

    void setNotificationPlaybackStateCompat(NotificationCompat.Builder builder) {
//        LogHelper.d(tag, "updateNotificationPlaybackStateCompat. mPlaybackStateCompat=" + mPlaybackStateCompat);
        if (exists playbackState = this.playbackState, started) {
            if (playbackState.state == PlaybackStateCompat.statePlaying,
                playbackState.position>=0) {
                //            LogHelper.d(tag, "updateNotificationPlaybackStateCompat. updating playback position to ",
                //                (System.currentTimeMillis() - playback.position) / 1000, " seconds");
                builder.setWhen(System.currentTimeMillis() - playbackState.position)
                    .setShowWhen(true)
                    .setUsesChronometer(true);
            } else {
                //            LogHelper.d(tag, "updateNotificationPlaybackStateCompat. hiding playback position");
                builder.setWhen(0)
                    .setShowWhen(false)
                    .setUsesChronometer(false);
            }
            builder.setOngoing(playbackState.state == PlaybackStateCompat.statePlaying);
        }
        else {
            service.stopForeground(true);
        }
    }

    void fetchBitmapFromURLAsync(String bitmapUrl, NotificationCompat.Builder builder) {
        AlbumArtCache.instance.fetch(bitmapUrl, (artUrl, bitmap, icon) {
            if (exists artUrl,
                exists uri = metadata?.description?.iconUri,
                uri.string==artUrl) {
//                LogHelper.d(tag, "fetchBitmapFromURLAsync: set bitmap to ", artUrl);
                builder.setLargeIcon(bitmap);
                notificationManager.notify(notificationId, builder.build());
            }
        });
    }

    Notification? createNotification() {
//        LogHelper.d(tag, "updateNotificationMetadata. mMetadata=" + mMetadata);
        if (exists metadata = this.metadata,
            exists playbackState = this.playbackState) {

            value notificationBuilder = NotificationCompat.Builder(service);
            Integer playPauseButtonPosition;
            if (playbackState.actions.and(PlaybackStateCompat.actionSkipToPrevious) != 0) {
                notificationBuilder.addAction(R.Drawable.ic_skip_previous_white_24dp,
                    service.getString(R.String.label_previous), previousIntent);
                playPauseButtonPosition = 1;
            }
            else {
                playPauseButtonPosition = 0;
            }
            addPlayPauseAction(notificationBuilder);
            if (playbackState.actions.and(PlaybackStateCompat.actionSkipToNext) != 0) {
                notificationBuilder.addAction(R.Drawable.ic_skip_next_white_24dp,
                    service.getString(R.String.label_next), nextIntent);
            }

            value description = metadata.description;

            String? fetchArtUrl;
            Bitmap? art;
            if (exists artUrl = description.iconUri?.string) {
                if (exists image = AlbumArtCache.instance.getBigImage(artUrl)) {
                    art = image;
                    fetchArtUrl = null;
                } else {
                    fetchArtUrl = artUrl;
                    art = BitmapFactory.decodeResource(service.resources, R.Drawable.ic_default_art);
                }
            }
            else {
                fetchArtUrl = null;
                art = null;
            }

            notificationBuilder.setStyle(NotificationCompat.MediaStyle()
                .setShowActionsInCompactView(playPauseButtonPosition)
                .setMediaSession(sessionToken))
                .setColor(notificationColor).setSmallIcon(R.Drawable.ic_notification)
                .setVisibility(Notification.visibilityPublic)
                .setUsesChronometer(true)
                .setContentIntent(createContentIntent(description))
                .setContentTitle(description.title)
                .setContentText(description.subtitle)
                .setLargeIcon(art);
            if (exists castName = controller?.extras?.getString(MusicService.extraConnectedCast)) {
                value castInfo = service.resources.getString(R.String.casting_to_device, castName);
                notificationBuilder.setSubText(castInfo);
                notificationBuilder.addAction(R.Drawable.ic_close_black_24dp,
                    service.getString(R.String.stop_casting), stopCastIntent);
            }
            setNotificationPlaybackStateCompat(notificationBuilder);
            if (exists fetchArtUrl) {
                fetchBitmapFromURLAsync(fetchArtUrl, notificationBuilder);
            }
            return notificationBuilder.build();
        }
        else {
            return null;
        }
    }

    object broadcastReceiver extends BroadcastReceiver() {
        suppressWarnings("caseNotDisjoint")
        shared actual void onReceive(Context context, Intent intent) {
//            LogHelper.d(tag, "Received intent with action " + action);
            switch (action = intent.action)
            case (actionPause) {
                transportControls?.pause();
            } case (actionPlay) {
                transportControls?.play();
            } case (actionNext) {
                transportControls?.skipToNext();
            } case (actionPrev) {
                transportControls?.skipToPrevious();
            } case (actionStopCasting) {
                value i = Intent(context, `MusicService`);
                i.setAction(MusicService.actionCmd);
                i.putExtra(MusicService.cmdName, MusicService.cmdStopCasting);
                service.startService(i);
            } else {
//                LogHelper.w(tag, "Unknown intent ignored. Action=", action);
            }
        }
    }

    late MediaControllerCompat.Callback mediaControllerCallback;

    shared void startNotification() {
        if (!started) {
            metadata = controller?.metadata;
            playbackState = controller?.playbackState;
            if (exists notification = createNotification()) {
                controller?.registerCallback(mediaControllerCallback);
                value filter = IntentFilter();
                filter.addAction(actionNext);
                filter.addAction(actionPause);
                filter.addAction(actionPlay);
                filter.addAction(actionPrev);
                filter.addAction(actionStopCasting);
                service.registerReceiver(broadcastReceiver, filter);
                service.startForeground(notificationId, notification);
                started = true;
            }
        }
    }

    shared void stopNotification() {
        if (started) {
            started = false;
            controller?.unregisterCallback(mediaControllerCallback);
            try {
                notificationManager.cancel(notificationId);
                service.unregisterReceiver(broadcastReceiver);
            }
            catch (IllegalArgumentException ex) {}
            service.stopForeground(true);
        }
    }

    void updateSessionToken(MusicService musicService) {
        value freshToken = musicService.currentToken;
        if (!Objects.equals(sessionToken, freshToken)) {
            controller?.unregisterCallback(mediaControllerCallback);
            sessionToken = freshToken;
            if (exists freshToken) {
                controller = MediaControllerCompat(musicService, freshToken);
                transportControls = controller?.transportControls;
                if (started) {
                    controller?.registerCallback(mediaControllerCallback);
                }
            }
        }
    }

    mediaControllerCallback = object extends MediaControllerCompat.Callback() {

        suppressWarnings("caseNotDisjoint")
        shared actual void onPlaybackStateChanged(PlaybackStateCompat state) {
            playbackState = state;
//            LogHelper.d(tag, "Received new playback state", state);
            switch (state.state)
            case (PlaybackStateCompat.stateStopped
                | PlaybackStateCompat.stateNone) {
                stopNotification();
            } else if (exists notification = createNotification()) {
                notificationManager.notify(notificationId, notification);
            }
        }

        shared actual void onMetadataChanged(MediaMetadataCompat metadata) {
            outer.metadata = metadata;
//            LogHelper.d(tag, "Received new metadata ", metadata);
            if (exists notification = createNotification()) {
                notificationManager.notify(notificationId, notification);
            }
        }

        shared actual void onSessionDestroyed() {
//            LogHelper.d(tag, "Session was destroyed, resetting to the new session token");
            try {
                updateSessionToken(service);
            }
            catch (RemoteException e) {
                //LogHelper.e(tag, e, "could not connect media controller");
            }
        }
    };

    updateSessionToken(service);

}
