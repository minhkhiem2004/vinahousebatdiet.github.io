from django.db import models
from django.contrib.auth.models import AbstractUser, Group, Permission

class Product(models.Model):
    name = models.CharField(max_length=255)
    price = models.DecimalField(max_digits=10, decimal_places=2)

class User(AbstractUser):
    avatar_url = models.URLField(max_length=255, blank=True, null=True)
    is_active = models.BooleanField(default=True)

    # Thêm related_name để tránh xung đột
    groups = models.ManyToManyField(Group, related_name="vinahouse_users_groups")
    user_permissions = models.ManyToManyField(Permission, related_name="vinahouse_users_permissions")
    ROLE_CHOICES = [
        ('user', 'User'),
        ('premium_user', 'Premium User'),
        ('artist', 'Artist'),
        ('admin', 'Admin'),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='user')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Artist(models.Model):
    name = models.CharField(max_length=255, unique=True)
    image_url = models.URLField(max_length=255, blank=True, null=True)
    verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class Genre(models.Model):
    name = models.CharField(max_length=255, unique=True)

class Song(models.Model):
    title = models.CharField(max_length=255)
    song_file_url = models.URLField(max_length=255)
    image_url = models.URLField(max_length=255, blank=True, null=True)
    duration = models.IntegerField()
    file_format = models.CharField(max_length=10)
    file_size = models.IntegerField()
    is_featured = models.BooleanField(default=False)
    is_approved = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    genres = models.ManyToManyField(Genre, through='SongGenre')
    artists = models.ManyToManyField(Artist, through='SongArtist')

class SongGenre(models.Model):
    song = models.ForeignKey(Song, on_delete=models.CASCADE)
    genre = models.ForeignKey(Genre, on_delete=models.CASCADE)

class SongArtist(models.Model):
    ROLE_CHOICES = [
        ('primary', 'Primary'),
        ('featured', 'Featured'),
        ('composer', 'Composer'),
        ('producer', 'Producer'),
    ]
    song = models.ForeignKey(Song, on_delete=models.CASCADE)
    artist = models.ForeignKey(Artist, on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='primary')

class Playlist(models.Model):
    name = models.CharField(max_length=255)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    is_public = models.BooleanField(default=False)
    cover_image_url = models.URLField(max_length=255, blank=True, null=True)
    song_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    songs = models.ManyToManyField(Song, through='PlaylistSong')

class PlaylistSong(models.Model):
    playlist = models.ForeignKey(Playlist, on_delete=models.CASCADE)
    song = models.ForeignKey(Song, on_delete=models.CASCADE)
    position = models.IntegerField()
    added_at = models.DateTimeField(auto_now_add=True)

class Favorite(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    song = models.ForeignKey(Song, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

class ListeningHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    song = models.ForeignKey(Song, on_delete=models.CASCADE)
    listened_at = models.DateTimeField(auto_now_add=True)
