import fetch from 'node-fetch'
import { parse as toHtml } from 'node-html-parser'

const title = (body) => {
    const html = toHtml(body)
    const titleTag = html.querySelector(`head > meta[property="og:title"]`)
    return titleTag.attributes[`content`]
}

const SONG_NAME_PREFIX = `Песня «`
const SONG_NAME_SUFFIX = `» (`
const ARTIST_NAME_SUFFIX = `)`

const clean = (title) => {
    const songName = title.substring(SONG_NAME_PREFIX.length, title.length)
    const [name, artist] = songName.split(SONG_NAME_SUFFIX)
    const artistName = artist.substring(0, artist.lastIndexOf(ARTIST_NAME_SUFFIX));
    return `${name} ${artistName}`
}

const load = async (link) => {
    const result = await fetch(link)
    if (!result.ok) throw new Error(`Failed to get response: ${result.status}`)

    return await result.text()
}

const print = console.log

load(`https://music.apple.com/ru/album/concave/1452118070?i=1452118072`)
    .then(title)
    .then(clean)
    .then(print)
    .catch((e) => console.error(e))
