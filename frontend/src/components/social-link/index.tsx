import Image from 'next/image';
import discordIcon from '../../../public/icons/discord.svg';
import twitterIcon from '../../../public/icons/twitter.svg';
import telegramIcon from '../../../public/icons/telegram.svg';
import githubIcon from '../../../public/icons/github.svg';
import mediumIcon from '../../../public/icons/medium.svg';
import css from './social-link.module.css';


interface SocialMeta {
    icon: string;
    title: string;
    url: string;
}

interface SocialStruct {
    [key: string]: SocialMeta;
}

const socials: SocialStruct = {
    twitter: {
        title: 'Twitter',
        icon: twitterIcon,
        url: 'https://www.twitter.com/DefiSyndicate'
    },
    discord: {
        title: 'Discord',
        icon: discordIcon,
        url: 'https://www.twitter.com/DefiSyndicate'
    },
    telegram: {
        title: 'Telegram',
        icon: telegramIcon,
        url: 'https://www.twitter.com/DefiSyndicate'
    },
    github: {
        title: 'Github',
        icon: githubIcon,
        url: 'https://github.com/DefiSyndicate'
    },
    medium: {
        title: 'Medium',
        icon: mediumIcon,
        url: 'https://medium.com/@DefiSyndicate'
    }
};

interface SocialLinkProps {
    title: string
}

const SocialLink = ({title}: SocialLinkProps): JSX.Element => {
    console.log(title);
    return (
        <div className={css.socialLinkContainer}>
            <a href={socials[title].url} target="_blank" rel="noreferrer"><Image height="24" width="24" alt={`${title} icon`} src={socials[title].icon}></Image></a>
        </div>
    );

}

export default SocialLink;