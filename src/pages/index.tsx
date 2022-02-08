import Head from 'next/head';
import Image from 'next/image';
import css from '../styles/Home.module.css';

export default function Home() {
  return (
      <div className={css.homeContainer}>
        <h1>Welcome to the Defi Syndicate</h1>
      </div>
  );
}
